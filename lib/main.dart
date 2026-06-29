import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // O Firebase deve ser iniciado aqui. Se houver erro de compilação, 
  // certifique-se de que o firebase_core está no pubspec.yaml
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
        useMaterial3: true,
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
  final List<Map<String, dynamic>> produtos = [
    {"nome": "Refrigerante", "preco": 8.00},
    {"nome": "Agua sem gas", "preco": 3.00},
    {"nome": "Agua com gas", "preco": 3.50},
    {"nome": "Suco Del Valle", "preco": 8.00},
    {"nome": "Pastel", "preco": 8.00},
    {"nome": "Salgado assado", "preco": 8.00},
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
        SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Controle de Caixa - Dia Com Maria"),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () {})
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12.0),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4, 
                  childAspectRatio: 1.3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: produtos.length,
                itemBuilder: (context, index) {
                  final prod = produtos[index];
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade50,
                      foregroundColor: Colors.blue.shade900,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.blue.shade200),
                      ),
                    ),
                    onPressed: () => adicionarAoCarrinho(prod),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(prod['nome'], textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        Text("R\$ ${prod['preco'].toStringAsFixed(2)}", style: const TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.grey.shade100,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Itens do Pedido", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(),
                  Expanded(
                    child: carrinho.isEmpty
                        ? const Center(child: Text("Nenhum item selecionado"))
                        : ListView.builder(
                            itemCount: carrinho.length,
                            itemBuilder: (context, index) {
                              final item = carrinho[index];
                              return Card(
                                child: ListTile(
                                  title: Text("${item['nome']} (x${item['quantidade']})"),
                                  trailing: Text("R\$ ${(item['preco'] * item['quantidade']).toStringAsFixed(2)}"),
                                  leading: IconButton(
                                    icon: const Icon(Icons.remove_circle, color: Colors.red),
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
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("TOTAL:", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text("R\$ ${totalPedido.toStringAsFixed(2)}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text("Pagamento:"),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: ["Dinheiro", "Pix", "Cartão"].map((forma) {
                      return ChoiceChip(
                        label: Text(forma),
                        selected: formaPagamento == forma,
                        onSelected: (val) => setState(() => formaPagamento = forma),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      onPressed: carrinho.isEmpty ? null : finalizarVenda,
                      child: const Text("FINALIZAR VENDA", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
