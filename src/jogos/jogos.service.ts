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
