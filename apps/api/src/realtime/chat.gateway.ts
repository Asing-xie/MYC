import { UsePipes, ValidationPipe } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { MessagesService } from '../messages/messages.service';
import { SendMessageDto } from '../messages/dto/send-message.dto';

type AuthedSocket = Socket & { user?: { id: string } };

@WebSocketGateway({
  cors: { origin: '*' },
  path: '/socket.io',
})
export class ChatGateway implements OnGatewayConnection {
  @WebSocketServer()
  server!: Server;

  constructor(
    private readonly jwtService: JwtService,
    private readonly messagesService: MessagesService,
  ) {}

  async handleConnection(client: AuthedSocket) {
    const token = client.handshake.auth?.token || client.handshake.headers.authorization?.replace('Bearer ', '');
    if (!token) {
      client.disconnect();
      return;
    }

    try {
      const payload = await this.jwtService.verifyAsync<{ id: string }>(token);
      client.user = { id: payload.id };
      client.join(`user:${payload.id}`);
    } catch {
      client.disconnect();
    }
  }

  @UsePipes(new ValidationPipe({ whitelist: true, transform: true }))
  @SubscribeMessage('message:send')
  async send(@ConnectedSocket() client: AuthedSocket, @MessageBody() dto: SendMessageDto) {
    if (!client.user) {
      client.disconnect();
      return;
    }

    const message = await this.messagesService.send(client.user.id, dto);
    const memberIds = await this.messagesService.conversationMemberIds(dto.conversationId);
    const rooms = [`conversation:${dto.conversationId}`, ...memberIds.map((userId) => `user:${userId}`)];
    this.server.to(rooms).emit('message:new', message);
    return message;
  }

  @SubscribeMessage('conversation:join')
  joinConversation(@ConnectedSocket() client: AuthedSocket, @MessageBody() body: { conversationId: string }) {
    client.join(`conversation:${body.conversationId}`);
    return { ok: true };
  }

  @SubscribeMessage('message:delivered')
  async delivered(@ConnectedSocket() client: AuthedSocket, @MessageBody() body: { messageId: string }) {
    if (!client.user) {
      client.disconnect();
      return;
    }

    const message = await this.messagesService.markDelivered(client.user.id, body.messageId);
    this.server.emit('message:status', { messageId: body.messageId, status: message.status });
    return message;
  }
}
