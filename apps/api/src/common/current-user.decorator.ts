import { createParamDecorator, ExecutionContext } from '@nestjs/common';

export type AuthUser = {
  id: string;
  email?: string | null;
  phone?: string | null;
};

export const CurrentUser = createParamDecorator((_: unknown, ctx: ExecutionContext): AuthUser => {
  const request = ctx.switchToHttp().getRequest<{ user: AuthUser }>();
  return request.user;
});
