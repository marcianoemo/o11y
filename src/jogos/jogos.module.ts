import { Module } from '@nestjs/common';
import { JogosController } from './jogos.controller';
import { JogosService } from './jogos.service';

@Module({
  controllers: [JogosController],
  providers: [JogosService],
})
export class JogosModule {}
