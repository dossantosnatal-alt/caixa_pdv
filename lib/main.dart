import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Verifica se já existe uma instância ativa para evitar o erro "duplicate-app"
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
      home: const TelaCaixa(),
    );
  }
}

class TelaCaixa extends StatefulWidget {
  const TelaCaixa({Key? key}) : super(key: key);

  @override
  _TelaCaixaState createState() => _TelaCaixaState();
}

class _TelaCaixaState extends State<TelaCaixa> {
  // Lista Oficial do Evento sincronizada com o seu Controle de Caixa
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

    try {
      final dadosVenda = {
        "caixa": "Caixa_01",
        "evento": "Dia Com Maria",
        "data_hora": FieldValue.serverTimestamp(),
        "forma_pagamento": formaPagamento,
        "total": totalPedido,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Controle de Caixa - Dia Com Maria"),
        backgroundColor: Colors.blue.shade700,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Produtos Disponíveis",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              // Grade de Produtos em formato vertical (3 colunas estável)
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

              // Container fixo para listagem do carrinho
              Container(
                height: 180, 
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
              const SizedBox(height: 6),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: ["Dinheiro", "Pix", "Cartão"].map((forma) {
                  return ChoiceChip(
                    label: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(forma),
                    ),
                    selected: formaPagamento == forma,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          formaPagamento = forma;
                        });
                      }
                    },
                  );
                }).toList(),
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
