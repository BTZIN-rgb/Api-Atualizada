import 'dart:convert';
import 'dart:io';
import 'package:mysql_dart/mysql_dart.dart';

Future<MySQLConnection> abrirConexao() async {
  final conexao = await MySQLConnection.createConnection(
    host: '127.0.0.1',
    port: 3306,
    userName: 'root',
    password: '',
    databaseName: 'oficinageral',
    secure: false,
  );

  await conexao.connect();
  return conexao;
}

Future<void> responder(HttpResponse resposta, int status, Object dados) async {
  resposta.statusCode = status;
  resposta.headers.contentType = ContentType('application', 'json', charset: 'utf-8');
  resposta.write(jsonEncode(dados));
  await resposta.close();
}

Future<void> atender(HttpRequest requisicao) async {
  final metodo = requisicao.method;
  final partes = requisicao.uri.pathSegments;
  MySQLConnection? conexao;

  try {
    if (partes.isEmpty) {
      await responder(requisicao.response, 404, {'erro': 'Rota nao encontrada.'});
      return;
    }

    final recurso = partes.first;

    // ================= ROTAS DE CLIENTES =================
    if (recurso == 'cliente') {
      conexao = await abrirConexao();

      if (metodo == 'GET') {
        final resultado = await conexao.execute(
          'SELECT `idCliente`, `nomeCliente`, `telefoneCliente`, `emailCliente` FROM `tabelacadastrocliente` ORDER BY `idCliente`',
        );
        final clientes = resultado.rows.map((linha) {
          final dados = linha.assoc();
          return {
            'idCliente': int.tryParse(dados['idCliente'] ?? '') ?? dados['idCliente'],
            'nomeCliente': dados['nomeCliente'],
            'telefoneCliente': dados['telefoneCliente'],
            'emailCliente': dados['emailCliente'],
          };
        }).toList();
        await responder(requisicao.response, 200, clientes);
        return;
      }

      if (metodo == 'POST') {
        final texto = await utf8.decoder.bind(requisicao).join();
        final dados = jsonDecode(texto);
        
        await conexao.execute(
          'INSERT INTO `tabelacadastrocliente` (`nomeCliente`, `telefoneCliente`, `emailCliente`) VALUES (:nome, :telefone, :email)',
          {
            'nome': dados['nomeCliente'],
            'telefone': dados['telefoneCliente'],
            'email': dados['emailCliente'],
          },
        );
        final resultadoId = await conexao.execute('SELECT LAST_INSERT_ID() AS id');
        final novoId = int.tryParse(resultadoId.rows.first.colByName('id') ?? '');
        await responder(requisicao.response, 201, {'idCliente': novoId, ...dados});
        return;
      }
    }

    // ================= ROTAS DE ESTOQUE =================
    if (recurso == 'estoque') {
      conexao = await abrirConexao();

      if (metodo == 'GET') {
        final resultado = await conexao.execute(
          'SELECT `idEstoque`, `modeloCarro`, `quantidadeEstoque`, `precoUnitario` FROM `tableestoquecarros` ORDER BY `idEstoque`',
        );
        final estoque = resultado.rows.map((linha) {
          final dados = linha.assoc();
          return {
            'idEstoque': int.tryParse(dados['idEstoque'] ?? '') ?? dados['idEstoque'],
            'modeloCarro': dados['modeloCarro'],
            'quantidadeEstoque': int.tryParse(dados['quantidadeEstoque'] ?? '') ?? dados['quantidadeEstoque'],
            'precoUnitario': double.tryParse(dados['precoUnitario'] ?? '') ?? dados['precoUnitario'],
          };
        }).toList();
        await responder(requisicao.response, 200, estoque);
        return;
      }

      if (metodo == 'POST') {
        final texto = await utf8.decoder.bind(requisicao).join();
        final dados = jsonDecode(texto);

        await conexao.execute(
          'INSERT INTO `tableestoquecarros` (`modeloCarro`, `quantidadeEstoque`, `precoUnitario`) VALUES (:modelo, :qtd, :preco)',
          {
            'modelo': dados['modeloCarro'],
            'qtd': dados['quantidadeEstoque'],
            'preco': dados['precoUnitario'],
          },
        );
        final resultadoId = await conexao.execute('SELECT LAST_INSERT_ID() AS id');
        final novoId = int.tryParse(resultadoId.rows.first.colByName('id') ?? '');
        await responder(requisicao.response, 201, {'idEstoque': novoId, ...dados});
        return;
      }
    }

    await responder(requisicao.response, 404, {'erro': 'Rota nao encontrada.'});
  } catch (erro) {
    stderr.writeln('Erro na API: $erro');
    await responder(requisicao.response, 500, {'erro': 'Erro interno no servidor ou banco de dados.'});
  } finally {
    await conexao?.close();
  }
}

Future<void> main() async {
  final servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 8080);
  print('API OficinaGeral rodando em http://localhost:8080/');
  await for (final requisicao in servidor) {
    atender(requisicao);
  }
}