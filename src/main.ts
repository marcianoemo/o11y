import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { ValidationPipe } from '@nestjs/common';
import { setupObservability } from './observability/instrumentation';

// Iniciar OpenTelemetry
setupObservability();

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.useGlobalPipes(new ValidationPipe());
  await app.listen(3333);
  console.log(`Aplicação rodando em: http://localhost:3333`);
}
bootstrap();
