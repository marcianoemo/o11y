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
