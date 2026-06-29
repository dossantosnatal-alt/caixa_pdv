import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicialização oficial do Firebase (com suporte offline nativo para os celulares)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Ativa o cache offline do Firestore
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  runApp(MaterialApp(
    home: const VerificarIdentificacao(),
    debugShowCheckedModeBanner: false,
  ));
}

// Tela intermediária que verifica se o caixa já foi configurado neste aparelho
class VerificarIdentificacao extends StatefulWidget {
  const VerificarIdentificacao({Key? key}) : super(key: key);

  @override
  _VerificarIdentificacaoState createState() => _VerificarIdentificacaoState();
}

class _VerificarIdentificacaoState extends State<VerificarIdentificacao> {
  @override
  void initState() {
    super.initState();
    verificarLogin();
  }

  void verificarLogin() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? caixaId = prefs.getString('caixa_id');
    if (caixaId != null && caixaId.isNotEmpty) {
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => CaixaPDV(caixaId: caixaId)));
    } else {
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ConfigurarCaixa()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

// TELA: Identificação Inicial do Caixa
class ConfigurarCaixa extends StatefulWidget {
  const ConfigurarCaixa({Key? key}) : super(key: key);

  @override
  _ConfigurarCaixaState createState() => _ConfigurarCaixaState();
}

class _ConfigurarCaixaState extends State<ConfigurarCaixa> {
  final TextEditingController _caixaCtrl = TextEditingController();
  final TextEditingController _operadorCtrl = TextEditingController();

  void salvarConfiguracao() async {
    if (_caixaCtrl.text.isNotEmpty && _operadorCtrl.text.isNotEmpty) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String idFormatado = "Caixa_${_caixaCtrl.text.padLeft(2, '0')}";
      await prefs.setString('caixa_id', idFormatado);
      await prefs.setString('operador_nome', _operadorCtrl.text);

      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => CaixaPDV(caixaId: idFormatado)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor, preencha todos os campos!")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade900,
      body: Center(
        child: Container(
          width: 350,
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("⚠️ Abertura de Caixa", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                controller: _caixaCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Número do Caixa (Ex: 1, 2...)", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _operadorCtrl,
                decoration: const InputDecoration(labelText: "Nome do Operador", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
                  onPressed: salvarConfiguracao,
                  child: const Text("ABRIR CAIXA", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// TELA: Frente de Caixa (Cardápio, Vendas e Abate de Estoque)
class CaixaPDV extends StatefulWidget {
  final String caixaId;
  const CaixaPDV({Key? key, required this.caixaId}) : super(key: key);

  @override
  _CaixaPDVState createState() => _CaixaPDVState();
}

class _CaixaPDVState extends State<CaixaPDV> {
  final List<Map<String, dynamic>> produtos = [
    {"nome": "Refrigerante", "preco": 8.00},
    {"nome": "Agua sem gas", "preco": 3.00},
    {"nome": "Agua com gas", "preco": 3.50},
    {"nome": "Suco Del Valle", "preco": 8.00},
    {"nome": "Pastel", "preco": 8.00},
    {"nome": "Salgado assado", "preco": 8.00},
  ];

  Map<String, int> carrinho = {};
  String formaPagamento = "";
  bool salvandoVenda = false;

  double get valorTotal {
    double total = 0.0;
    carrinho.forEach((nome, qtd) {
      var p = produtos.firstWhere((prod) => prod["nome"] == nome);
      total += p["preco"] * qtd;
    });
    return total;
  }

  void adicionarItem(String nome) {
    setState(() {
      carrinho[nome] = (carrinho[nome] ?? 0) + 1;
    });
  }

  // Função transacional: Garante que o estoque seja verificado e diminuído na nuvem com segurança
  Future<void> finalizarVendaNoFirebase() async {
    setState(() {
      salvandoVenda = true;
    });

    try {
      // Usamos uma transação para evitar que dois caixas vendam o mesmo item sem estoque ao mesmo tempo
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        List<DocumentReference> refs = [];
        List<DocumentSnapshot> snapshots = [];

        // 1. Ler o estoque de todos os itens do carrinho primeiro
        for (String produtoNome in carrinho.keys) {
          DocumentReference ref = FirebaseFirestore.instance.collection('estoque').doc(produtoNome);
          DocumentSnapshot snap = await transaction.get(ref);
          refs.add(ref);
          snapshots.add(snap);
        }

        // 2. Verificar se há quantidade suficiente para todos os itens
        for (int i = 0; i < carrinho.keys.length; i++) {
          String produtoNome = carrinho.keys.elementAt(i);
          int qtdPedida = carrinho[produtoNome]!;
          DocumentSnapshot snap = snapshots[i];

          if (!snap.exists) {
            throw "O produto '$produtoNome' não foi localizado no estoque da nuvem.";
          }

          int estoqueAtual = (snap.data() as Map<String, dynamic>)['quantidade'] ?? 0;
          if (estoqueAtual < qtdPedida) {
            throw "Estoque insuficiente para '$produtoNome'. Disponível: $estoqueAtual";
          }
        }

        // 3. Se tudo estiver correto, abate o estoque item por item
        for (int i = 0; i < carrinho.keys.length; i++) {
          String produtoNome = carrinho.keys.elementAt(i);
          int qtdPedida = carrinho[produtoNome]!;
          int estoqueAtual = (snapshots[i].data() as Map<String, dynamic>)['quantidade'] ?? 0;
          
          transaction.update(refs[i], {'quantidade': estoqueAtual - qtdPedida});
        }

        // 4. Salva a venda concluída na coleção de vendas
        DocumentReference vendaRef = FirebaseFirestore.instance.collection('vendas').doc();
        transaction.set(vendaRef, {
          'itens': carrinho,
          'valor_total': valorTotal,
          'forma_pagamento': formaPagamento,
          'data_hora': FieldValue.serverTimestamp(),
          'caixa_id': widget.caixaId
        });
      });

      setState(() {
        carrinho.clear();
        formaPagamento = "";
        salvandoVenda = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Venda registrada e estoque atualizado!", style: TextStyle(fontSize: 16)),
          backgroundColor: Colors.green,
        )
      );
    } catch (e) {
      setState(() {
        salvandoVenda = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro: $e", style: TextStyle(fontSize: 16)),
          backgroundColor: Colors.red,
        )
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Frente de Caixa [ ${widget.caixaId} ] - Meliponário São José", style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue.shade800,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (!mounted) return;
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ConfigurarCaixa()));
            },
          )
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 3,
            child: GridView.builder(
              padding: const EdgeInsets.all(15),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, 
                crossAxisSpacing: 12, 
                mainAxisSpacing: 12, 
                childAspectRatio: 1.4
              ),
              itemCount: produtos.length,
              itemBuilder: (context, index) {
                var prod = produtos[index];
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade50,
                    side: BorderSide(color: Colors.blue.shade200, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => adicionarItem(prod["nome"]),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(prod["nome"], 
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                      const SizedBox(height: 8),
                      Text("R\$ ${prod["preco"].toStringAsFixed(2)}", 
                          style: TextStyle(color: Colors.green.shade800, fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              },
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.grey.shade100,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Itens do Pedido", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView(
                      children: carrinho.entries.map((e) => Card(
                        elevation: 0,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text("${e.value}x ${e.key}", style: const TextStyle(fontWeight: FontWeight.bold)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => setState(() => carrinho.remove(e.key)),
                          ),
                        ),
                      )).toList(),
                    ),
                  ),
                  const Divider(thickness: 2),
                  const SizedBox(height: 10),
                  Text("TOTAL: R\$ ${valorTotal.toStringAsFixed(2)}", 
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                  const SizedBox(height: 20),
                  const Text("Forma de Pagamento:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: ["Dinheiro", "Pix", "Cartão"].map((tipo) {
                      final bool selecionado = formaPagamento == tipo;
                      return ChoiceChip(
                        label: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                          child: Text(
                            tipo, 
                            style: TextStyle(
                              fontSize: 14, 
                              fontWeight: FontWeight.bold,
                              color: selecionado ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        selected: selecionado,
                        selectedColor: Colors.blue.shade800,
                        onSelected: (val) => setState(() => formaPagamento = val ? tipo : ""),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: (valorTotal > 0 && formaPagamento.isNotEmpty && !salvandoVenda) 
                        ? finalizarVendaNoFirebase 
                        : null,
                      child: salvandoVenda 
                        ? const Center(child: CircularProgressIndicator(color: Colors.white))
                        : const Text("FINALIZAR VENDA", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
