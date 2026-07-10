import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { AuthModule } from './auth/auth.module';
import { ContactsModule } from './contacts/contacts.module';
import { ConversationsModule } from './conversations/conversations.module';
import { MessagesModule } from './messages/messages.module';
import { PrismaModule } from './prisma/prisma.module';
import { RealtimeModule } from './realtime/realtime.module';
import { UploadsModule } from './uploads/uploads.module';
import { UsersModule } from './users/users.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    AuthModule,
    UsersModule,
    ContactsModule,
    ConversationsModule,
    MessagesModule,
    UploadsModule,
    RealtimeModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
