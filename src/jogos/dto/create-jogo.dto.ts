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
