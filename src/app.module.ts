import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { JogosModule } from './jogos/jogos.module';
import { PrismaModule } from './prisma/prisma.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
    }),
    PrismaModule,
    JogosModule,
  ],
})
export class AppModule {}
