import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (e) {
    print("Erro ao inicializar Firebase: $e");
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Controle de Caixa - Dia Com Maria',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: false,
      ),
      home: TelaCaixa(),
    );
  }
}

class TelaCaixa extends StatefulWidget {
  TelaCaixa({Key? key}) : super(key: key);

  @override
  _TelaCaixaState createState() => _TelaCaixaState();
}

class _TelaCaixaState extends State<TelaCaixa> {
  final List<Map<String, dynamic>> produtos = [
    {"nome": "Cachorro Quente", "preco": 8.00},
    {"nome": "Caldo de feijao", "preco": 12.00},
    {"nome": "Canjicada", "preco": 10.00},
    {"nome": "Canjiquinha", "preco": 12.00},
    {"nome": "Mini Pizza", "preco": 8.00},
    {"nome": "Pastel", "preco": 8.00},
    {"nome": "Salgado assado", "preco": 8.00},
    {"nome": "Bolo", "preco": 5.00},
    {"nome": "Pipoca", "preco": 5.00},
    {"nome": "Maçã do Amor", "preco": 10.00},
    {"nome": "Refrigerante", "preco": 8.00},
    {"nome": "Suco", "preco": 3.00},
    {"nome": "Agua com gás", "preco": 4.00},
    {"nome": "Agua sem gás", "preco": 3.00},
    {"nome": "Quentão", "preco": 8.00},
    {"nome": "Brincadeiras", "preco": 5.00},
  ];

  List<Map<String, dynamic>> carrinho = [];
  String formaPagamento = "Dinheiro";
  String nomeOperador = ""; // Nome digitado ao abrir o app
  
  final TextEditingController _sangriaController = TextEditingController();
  final TextEditingController _operadorController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pede o nome do operador assim que a tela é desenhada
    WidgetsBinding.instance.addPostFrameCallback((_) => _abrirModalDefinirOperador());
  }

  double get totalPedido {
    return carrinho.fold(0, (sum, item) => sum + (item['preco'] * item['quantidade']));
  }

  void adicionarAoCarrinho(Map<String, dynamic> produto) {
    setState(() {
      final index = carrinho.indexWhere((item) => item['nome'] == produto['nome']);
      if (index >= 0) {
        carrinho[index]['quantidade']++;
      } else {
        carrinho.add({
          "nome": produto['nome'],
          "preco": produto['preco'],
          "quantidade": 1,
        });
      }
    });
  }

  void finalizarVenda() async {
    if (carrinho.isEmpty) return;
    final String identificadorCaixa = nomeOperador.trim().isEmpty ? "Operador Geral" : nomeOperador.trim();

    try {
      final dadosVenda = {
        "caixa": identificadorCaixa,
        "evento": "Dia Com Maria",
        "data_hora": FieldValue.serverTimestamp(),
        "forma_pagamento": formaPagamento,
        "total": totalPedido,
        "tipo": "venda",
        "itens": carrinho.map((item) => {
          "nome": item['nome'],
          "preco_unitario": item['preco'],
          "quantidade": item['quantidade'],
          "subtotal": item['preco'] * item['quantidade']
        }).toList(),
      };

      await FirebaseFirestore.instance.collection('vendas').add(dadosVenda);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Venda finalizada com sucesso!'), backgroundColor: Colors.green),
      );

      setState(() {
        carrinho.clear();
        formaPagamento = "Dinheiro";
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar no Firebase: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void registrarSangria() async {
    final double? valor = double.tryParse(_sangriaController.text.replaceFirst(',', '.'));
    if (valor == null || valor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insira um valor válido de sangria'), backgroundColor: Colors.orange),
      );
      return;
    }

    final String identificadorCaixa = nomeOperador.trim().isEmpty ? "Operador Geral" : nomeOperador.trim();

    try {
      final dadosSangria = {
        "caixa": identificadorCaixa,
        "evento": "Dia Com Maria",
        "data_hora": FieldValue.serverTimestamp(),
        "forma_pagamento": "Dinheiro",
        "total": valor,
        "tipo": "sangria",
        "itens": []
      };

      await FirebaseFirestore.instance.collection('vendas').add(dadosSangria);
      _sangriaController.clear();
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sangria registrada com sucesso!'), backgroundColor: Colors.blue),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao registrar sangria: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _abrirModalSangria() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Registrar Sangria / Retirada"),
        content: TextField(
          controller: _sangriaController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: "Valor da Retirada (R\$)",
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.money_off, color: Colors.red),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("CANCELAR", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: registrarSangria,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("CONFIRMAR"),
          ),
        ],
      ),
    );
  }

  void _abrirModalDefinirOperador() {
    showDialog(
      context: context,
      barrierDismissible: false, // Força a preencher o nome
      builder: (context) => AlertDialog(
        title: const Text("Identificação do Caixa"),
        content: TextField(
          controller: _operadorController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: "Nome do Operador ou Caixa (Ex: Natal, Caixa 1)",
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              if (_operadorController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Por favor, informe seu nome para continuar.'), backgroundColor: Colors.orange),
                );
                return;
              }
              setState(() {
                nomeOperador = _operadorController.text.trim();
              });
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700),
            child: const Text("ENTRAR NO CAIXA"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String identificadorCaixa = nomeOperador.isEmpty ? "Identificando..." : nomeOperador;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Controle de Caixa - Dia Com Maria"),
        backgroundColor: Colors.blue.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.money_off),
            tooltip: "Registrar Sangria",
            onPressed: nomeOperador.isEmpty ? null : _abrirModalSangria,
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            tooltip: "Trocar Operador",
            onPressed: _abrirModalDefinirOperador,
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 📊 PAINEL DO SALDO ONLINE FILTRADO POR OPERADOR
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('vendas')
                    .where('caixa', isEqualTo: identificadorCaixa)
                    .snapshots(),
                builder: (context, snapshot) {
                  double totalVendas = 0;
                  double totalSangrias = 0;

                  if (snapshot.hasData) {
                    for (var doc in snapshot.data!.docs) {
                      final dados = doc.data() as Map<String, dynamic>;
                      final double valor = (dados['total'] as num?)?.toDouble() ?? 0.0;
                      final String tipo = dados['tipo'] ?? 'venda';

                      if (tipo == 'sangria') {
                        totalSangrias += valor;
                      } else {
                        totalVendas += valor;
                      }
                    }
                  }

                  double saldoAtual = totalVendas - totalSangrias;

                  return Card(
                    color: Colors.blue.shade900,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Operador: $identificadorCaixa",
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              const Icon(Icons.sync, color: Colors.greenAccent, size: 16),
                            ],
                          ),
                          const Divider(color: Colors.white24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  const Text("Vendas (+)", style: TextStyle(color: Colors.white60, fontSize: 11)),
                                  Text("R\$ ${totalVendas.toStringAsFixed(2)}", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Column(
                                children: [
                                  const Text("Sangrias (-)", style: TextStyle(color: Colors.white60, fontSize: 11)),
                                  Text("R\$ ${totalSangrias.toStringAsFixed(2)}", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Column(
                                children: [
                                  const Text("Saldo em Caixa", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                  Text(
                                    "R\$ ${saldoAtual.toStringAsFixed(2)}",
                                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              const Text(
                "Produtos Disponíveis",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,     
                  childAspectRatio: 1.2, 
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: produtos.length,
                itemBuilder: (context, index) {
                  final prod = produtos[index];
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade50,
                      foregroundColor: Colors.blue.shade900,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.blue.shade200, width: 1.2),
                      ),
                    ),
                    onPressed: () => adicionarAoCarrinho(prod),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          prod['nome'],
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "R\$ ${prod['preco'].toStringAsFixed(2)}",
                          style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              const Divider(thickness: 1.5),
              const SizedBox(height: 8),
              const Text(
                "Itens do Pedido (Carrinho)",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                height: 150, 
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: carrinho.isEmpty
                    ? const Center(
                        child: Text(
                          "Nenhum item adicionado ao carrinho",
                          style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                        ),
                      )
                    : ListView.builder(
                        itemCount: carrinho.length,
                        itemBuilder: (context, index) {
                          final item = carrinho[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: ListTile(
                              dense: true,
                              title: Text(
                                "${item['nome']} (x${item['quantidade']})",
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              trailing: Text(
                                "R\$ ${(item['preco'] * item['quantidade']).toStringAsFixed(2)}",
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              leading: IconButton(
                                icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
                                onPressed: () {
                                  setState(() {
                                    if (item['quantidade'] > 1) {
                                      item['quantidade']--;
                                    } else {
                                      carrinho.removeAt(index);
                                    }
                                  });
                                },
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("TOTAL DO PEDIDO:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(
                    "R\$ ${totalPedido.toStringAsFixed(2)}",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text("Forma de Pagamento:", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: formaPagamento == "Dinheiro" ? Colors.blue.shade700 : Colors.grey.shade200,
                          foregroundColor: formaPagamento == "Dinheiro" ? Colors.white : Colors.black87,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => setState(() => formaPagamento = "Dinheiro"),
                        child: const Text("Dinheiro", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: formaPagamento == "Pix" ? Colors.blue.shade700 : Colors.grey.shade200,
                          foregroundColor: formaPagamento == "Pix" ? Colors.white : Colors.black87,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => setState(() => formaPagamento = "Pix"),
                        child: const Text("Pix", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: formaPagamento == "Cartão" ? Colors.blue.shade700 : Colors.grey.shade200,
                          foregroundColor: formaPagamento == "Cartão" ? Colors.white : Colors.black87,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => setState(() => formaPagamento = "Cartão"),
                        child: const Text("Cartão", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: carrinho.isEmpty ? Colors.grey.shade400 : Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: carrinho.isEmpty ? null : finalizarVenda,
                  child: const Text("FINALIZAR VENDA", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
