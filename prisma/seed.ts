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
