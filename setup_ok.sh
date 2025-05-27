#!/bin/bash

echo "🔄 Corrigindo erros do Prisma no Docker Alpine..."

# Verificar se o Docker está instalado
if ! command -v docker &> /dev/null; then
    echo "❌ Docker não encontrado. Por favor, instale o Docker antes de continuar."
    exit 1
fi

# Parar e remover tudo
echo "🧹 Limpando recursos existentes..."
docker-compose down --volumes --remove-orphans
docker rm -f $(docker ps -a -q --filter name=game-catalog* 2>/dev/null) 2>/dev/null || true
docker rmi -f $(docker images -q --filter reference='*_api' 2>/dev/null) 2>/dev/null || true
docker rmi -f $(docker images -q --filter reference='game-catalog*' 2>/dev/null) 2>/dev/null || true
docker builder prune -f

# Criar estrutura de diretórios
echo "📁 Criando estrutura de diretórios..."
mkdir -p prisma
mkdir -p src/prisma
mkdir -p src/jogos/dto
mkdir -p src/observability

# Criar Dockerfile
echo "📝 Criando Dockerfile com suporte a bibliotecas necessárias..."
cat > Dockerfile << 'EOL'
FROM node:18

WORKDIR /app

COPY package*.json ./

RUN npm install

COPY . .

RUN npx prisma generate

EXPOSE 3333

CMD ["npm", "start"]
EOL


# Criar arquivo docker-compose.yml
echo "📝 Criando docker-compose.yml..."
cat > docker-compose.yml << 'EOL'
version: '3.8'

services:
  api:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "3333:3333"
    environment:
      - DATABASE_URL=postgresql://postgres:postgres@postgres_app:5432/game_catalog?schema=public
      - OTEL_SERVICE_NAME=game-catalog-api
      - OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318
    restart: unless-stopped
    volumes:
      - ./prisma:/app/prisma
      - ./src:/app/src
    networks:
      - monitoring

networks:
  monitoring:
    driver: bridge
    external: true
EOL

# Criar arquivo package.json
echo "📝 Criando package.json..."
cat > package.json << 'EOL'
{
  "name": "game-catalog-api",
  "version": "0.0.1",
  "description": "API de catálogo de jogos para colecionadores",
  "private": true,
  "license": "MIT",
  "engines": {
    "npm": ">=10.0.0"
  },
  "scripts": {
    "start": "ts-node src/main.ts",
    "prisma:generate": "prisma generate",
    "prisma:migrate": "prisma migrate dev",
    "prisma:studio": "prisma studio",
    "prisma:seed": "ts-node prisma/seed.ts"
  },
  "dependencies": {
    "@nestjs/common": "^10.0.0",
    "@nestjs/config": "^3.1.1",
    "@nestjs/core": "^10.0.0",
    "@nestjs/mapped-types": "^2.0.0",
    "@nestjs/platform-express": "^10.0.0",
    "@prisma/client": "^5.7.0",
    "class-transformer": "^0.5.1",
    "class-validator": "^0.14.0",
    "reflect-metadata": "^0.1.13",
    "rxjs": "^7.8.1",
    "@types/supertest": "^6.0.3",
    "@types/node": "^22.15.18",
    "@types/jest": "^29.5.14",
    "@opentelemetry/api": "1.9.0",
    "@opentelemetry/sdk-node": "0.201.1",
    "@opentelemetry/sdk-trace-base": "2.0.1",
    "@opentelemetry/resources": "2.0.1",
    "@opentelemetry/semantic-conventions": "1.33.1",
    "@opentelemetry/exporter-trace-otlp-http": "0.201.1",
    "@opentelemetry/auto-instrumentations-node": "0.59.0",
    "@opentelemetry/sdk-metrics": "^2.0.1",
    "@opentelemetry/exporter-metrics-otlp-http": "^0.201.1",
    "@opentelemetry/exporter-metrics-otlp-proto": "^0.201.1",
    "@opentelemetry/exporter-trace-otlp-proto": "^0.201.1",
    "@prisma/instrumentation": "^6.8.2"
  },
  "devDependencies": {
    "@types/express": "^4.17.17",
    "@types/node": "^20.3.1",
    "prisma": "^5.7.0",
    "ts-node": "^10.9.1",
    "typescript": "^5.1.3"
  }
}
EOL

# Criar um tsconfig.json
echo "📝 Criando tsconfig.json..."
cat > tsconfig.json << 'EOL'
{
  "compilerOptions": {
    "module": "commonjs",
    "declaration": true,
    "removeComments": true,
    "emitDecoratorMetadata": true,
    "experimentalDecorators": true,
    "allowSyntheticDefaultImports": true,
    "target": "ES2021",
    "sourceMap": true,
    "outDir": "./dist",
    "baseUrl": "./",
    "incremental": true,
    "skipLibCheck": true,
    "strictNullChecks": false,
    "noImplicitAny": false,
    "strictBindCallApply": false,
    "forceConsistentCasingInFileNames": false,
    "noFallthroughCasesInSwitch": false
  }
}
EOL

# Criar arquivo instrumentation.ts
echo "📝 Criando instrumentation..."
cat > src/observability/instrumentation.ts << 'EOL'
import * as opentelemetry from '@opentelemetry/sdk-node';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-proto';
import { OTLPMetricExporter } from '@opentelemetry/exporter-metrics-otlp-proto';
import { PeriodicExportingMetricReader } from '@opentelemetry/sdk-metrics';
import { PrismaInstrumentation } from '@prisma/instrumentation';

const sdk = new opentelemetry.NodeSDK({
  traceExporter: new OTLPTraceExporter({
    // optional - default url is http://localhost:4318/v1/traces
    url: 'http://otel-collector:4318/v1/traces',
    // optional - collection of custom headers to be sent with each request, empty by default
    headers: {},
  }),
  metricReader: new PeriodicExportingMetricReader({
    exporter: new OTLPMetricExporter({
      url: 'http://otel-collector:4318/v1/metrics', // url is optional and can be omitted - default is http://localhost:4318/v1/metrics
      headers: {}, // an optional object containing custom headers to be sent with each request
    }),
  }),
  instrumentations: [getNodeAutoInstrumentations(),
  new PrismaInstrumentation({
      middleware: true,
    }),
  ],
});

export function setupObservability() {
  // Iniciar SDK
  sdk.start();
  console.log('OpenTelemetry: Instrumentação iniciada');

  // Garantir encerramento limpo
  process.on('SIGTERM', () => {
    sdk.shutdown()
      .then(() => console.log('OpenTelemetry: Instrumentação encerrada'))
      .catch((error) => console.error('OpenTelemetry: Erro ao encerrar instrumentação', error))
      .finally(() => process.exit(0));
  });
}
EOL

# Criar arquivo schema.prisma
echo "📝 Criando schema.prisma..."
cat > prisma/schema.prisma << 'EOL'
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model Jogo {
  id         Int      @id @default(autoincrement())
  nome       String   @db.VarChar(100)
  plataforma String   @db.VarChar(50)
  genero     String   @db.VarChar(50)
  valorPago  Decimal  @db.Decimal(10, 2)
}
EOL

# Criar arquivo seed.ts
echo "📝 Criando seed.ts..."
cat > prisma/seed.ts << 'EOL'
import { PrismaClient } from '@prisma/client';
import { Prisma } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  // Limpar dados existentes
  await prisma.jogo.deleteMany({});

  // Dados iniciais de jogos
  const jogos = [
    {
      nome: 'The Last of Us Part II',
      plataforma: 'playstation',
      genero: 'aventura',
      valorPago: new Prisma.Decimal(199.90),
    },
    {
      nome: 'God of War Ragnarok',
      plataforma: 'playstation',
      genero: 'acao',
      valorPago: new Prisma.Decimal(249.90),
    },
    {
      nome: 'Halo Infinite',
      plataforma: 'xbox',
      genero: 'tiro',
      valorPago: new Prisma.Decimal(199.90),
    },
    {
      nome: 'Forza Horizon 5',
      plataforma: 'xbox',
      genero: 'corrida',
      valorPago: new Prisma.Decimal(179.90),
    },
    {
      nome: 'Zelda: Breath of the Wild',
      plataforma: 'nintendo',
      genero: 'aventura',
      valorPago: new Prisma.Decimal(299.90),
    },
  ];

  // Inserir jogos
  for (const jogo of jogos) {
    await prisma.jogo.create({
      data: jogo,
    });
  }

  console.log('Dados iniciais inseridos com sucesso!');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
EOL

# Criar arquivo prisma.service.ts
echo "📝 Criando prisma.service.ts..."
cat > src/prisma/prisma.service.ts << 'EOL'
import { Injectable, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  constructor() {
    super();
  }

  async onModuleInit() {
    await this.$connect();
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }
}
EOL

# Criar arquivo prisma.module.ts
echo "📝 Criando prisma.module.ts..."
cat > src/prisma/prisma.module.ts << 'EOL'
import { Global, Module } from '@nestjs/common';
import { PrismaService } from './prisma.service';

@Global()
@Module({
  providers: [PrismaService],
  exports: [PrismaService],
})
export class PrismaModule {}
EOL

# Criar arquivo create-jogo.dto.ts
echo "📝 Criando DTOs..."
cat > src/jogos/dto/create-jogo.dto.ts << 'EOL'
import { IsNotEmpty, IsNumber, IsString, Min } from 'class-validator';

export class CreateJogoDto {
  @IsNotEmpty()
  @IsString()
  nome: string;

  @IsNotEmpty()
  @IsString()
  plataforma: string;

  @IsNotEmpty()
  @IsString()
  genero: string;

  @IsNotEmpty()
  @IsNumber()
  @Min(0)
  valorPago: number;
}
EOL

# Criar arquivo update-jogo.dto.ts
cat > src/jogos/dto/update-jogo.dto.ts << 'EOL'
import { PartialType } from '@nestjs/mapped-types';
import { CreateJogoDto } from './create-jogo.dto';

export class UpdateJogoDto extends PartialType(CreateJogoDto) {}
EOL

# Criar arquivo jogos.service.ts
echo "📝 Criando service, controller e module..."
cat > src/jogos/jogos.service.ts << 'EOL'
import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateJogoDto } from './dto/create-jogo.dto';
import { UpdateJogoDto } from './dto/update-jogo.dto';
import { Prisma } from '@prisma/client';

@Injectable()
export class JogosService {
  constructor(private prisma: PrismaService) {}

  // Criar um novo jogo
  async create(createJogoDto: CreateJogoDto) {
    return this.prisma.jogo.create({
      data: {
        ...createJogoDto,
        valorPago: new Prisma.Decimal(createJogoDto.valorPago),
      },
    });
  }

  // Buscar todos os jogos
  async findAll() {
    return this.prisma.jogo.findMany();
  }

  // Buscar um jogo pelo ID
  async findOne(id: number) {
    const jogo = await this.prisma.jogo.findUnique({
      where: { id },
    });

    if (!jogo) {
      throw new NotFoundException(`Jogo com ID ${id} não encontrado`);
    }

    return jogo;
  }

  // Buscar jogos por plataforma
  async findByPlataforma(plataforma: string) {
    return this.prisma.jogo.findMany({
      where: {
        plataforma: {
          equals: plataforma,
          mode: 'insensitive',
        },
      },
    });
  }

  // Buscar jogos por gênero
  async findByGenero(genero: string) {
    return this.prisma.jogo.findMany({
      where: {
        genero: {
          equals: genero,
          mode: 'insensitive',
        },
      },
    });
  }

  // Atualizar um jogo
  async update(id: number, updateJogoDto: UpdateJogoDto) {
    // Verifica se o jogo existe antes de atualizar
    await this.findOne(id);

    // Prepara os dados para atualização
    const data: any = { ...updateJogoDto };
    if (updateJogoDto.valorPago !== undefined) {
      data.valorPago = new Prisma.Decimal(updateJogoDto.valorPago);
    }

    return this.prisma.jogo.update({
      where: { id },
      data,
    });
  }

  // Remover um jogo
  async remove(id: number) {
    // Verifica se o jogo existe antes de remover
    await this.findOne(id);

    await this.prisma.jogo.delete({
      where: { id },
    });
  }
}
EOL

# Criar arquivo jogos.controller.ts
cat > src/jogos/jogos.controller.ts << 'EOL'
import {
  Controller,
  Get,
  Post,
  Body,
  Patch,
  Param,
  Delete,
  ParseIntPipe,
} from '@nestjs/common';
import { JogosService } from './jogos.service';
import { CreateJogoDto } from './dto/create-jogo.dto';
import { UpdateJogoDto } from './dto/update-jogo.dto';

@Controller('jogos')
export class JogosController {
  constructor(private readonly jogosService: JogosService) {}

  // Rota para criar um novo jogo - POST /jogos
  @Post()
  create(@Body() createJogoDto: CreateJogoDto) {
    return this.jogosService.create(createJogoDto);
  }

  // Rota para listar todos os jogos - GET /jogos
  @Get()
  findAll() {
    return this.jogosService.findAll();
  }

  // Rota para buscar jogos por plataforma - GET /jogos/plataforma/xbox
  @Get('plataforma/:plataforma')
  findByPlataforma(@Param('plataforma') plataforma: string) {
    return this.jogosService.findByPlataforma(plataforma);
  }

  // Rota para buscar jogos por gênero - GET /jogos/genero/aventura
  @Get('genero/:genero')
  findByGenero(@Param('genero') genero: string) {
    return this.jogosService.findByGenero(genero);
  }

  // Rota para buscar um jogo pelo ID - GET /jogos/1
  @Get(':id')
  findOne(@Param('id', ParseIntPipe) id: number) {
    return this.jogosService.findOne(id);
  }

  // Rota para atualizar um jogo - PATCH /jogos/1
  @Patch(':id')
  update(
    @Param('id', ParseIntPipe) id: number,
    @Body() updateJogoDto: UpdateJogoDto,
  ) {
    return this.jogosService.update(id, updateJogoDto);
  }

  // Rota para remover um jogo - DELETE /jogos/1
  @Delete(':id')
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.jogosService.remove(id);
  }
}
EOL

# Criar arquivo jogos.module.ts
cat > src/jogos/jogos.module.ts << 'EOL'
import { Module } from '@nestjs/common';
import { JogosController } from './jogos.controller';
import { JogosService } from './jogos.service';

@Module({
  controllers: [JogosController],
  providers: [JogosService],
})
export class JogosModule {}
EOL

# Criar arquivo app.module.ts
cat > src/app.module.ts << 'EOL'
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
EOL

# Criar arquivo main.ts
cat > src/main.ts << 'EOL'
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
EOL

# Criar arquivo .env
cat > .env << 'EOL'
DATABASE_URL="postgresql://postgres:postgres@postgres_app:5432/game_catalog?schema=public"
EOL

echo "🔨 Construindo e iniciando os containers..."
docker-compose up -d --build

echo "⏳ Aguardando o PostgreSQL inicializar..."
sleep 15

echo "🔄 Executando migrações do banco de dados..."
docker-compose exec api npx prisma migrate dev --name init

echo "🌱 Populando o banco de dados com dados iniciais..."
docker-compose exec api npm run prisma:seed

echo "✅ API de Catálogo de Jogos está rodando em http://localhost:3333"
echo ""
echo "Para testar a API, execute:"
echo "curl http://localhost:3333/jogos"
echo ""
echo "Para visualizar os logs, execute: docker-compose logs -f"
echo "Para parar a aplicação, execute: docker-compose down"
echo "Para acessar o Prisma Studio, execute: docker-compose exec -p 5555:5555 api npx prisma studio --host 0.0.0.0"