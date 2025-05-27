-- CreateTable
CREATE TABLE "Jogo" (
    "id" SERIAL NOT NULL,
    "nome" VARCHAR(100) NOT NULL,
    "plataforma" VARCHAR(50) NOT NULL,
    "genero" VARCHAR(50) NOT NULL,
    "valorPago" DECIMAL(10,2) NOT NULL,

    CONSTRAINT "Jogo_pkey" PRIMARY KEY ("id")
);
