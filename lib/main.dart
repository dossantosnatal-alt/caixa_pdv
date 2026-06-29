import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
  // Lista oficial de produtos do evento
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
      body: Column( // Alterado para Column para empilhar verticalmente
        children: [
          // PARTE DE CIMA: Grade de Produtos (3 colunas se ajusta melhor na vertical)
          Expanded(
            flex: 4, 
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(10.0),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, // 3 botões por linha na vertical     
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.blue.shade200, width: 1.5),
                      ),
                    ),
                    onPressed: () => adicionarAoCarrinho(prod),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          prod['nome'],
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "R\$ ${prod['preco'].toStringAsFixed(2)}",
                          style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // PARTE DE BAIXO: Carrinho e Botão de Finalizar
          Expanded(
            flex: 5,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(top: BorderSide(color: Colors.grey.shade300, width: 2.0)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Itens do Pedido",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Divider(thickness: 1),

                  // LISTA DOS ITENS ADICIONADOS
                  Expanded(
                    child: carrinho.isEmpty
                        ? const Center(
                            child: Text(
                              "Carrinho vazio",
                              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                            ),
                          )
                        : ListView.builder(
                            itemCount: carrinho.length,
                            itemBuilder: (context, index) {
                              final item = carrinho[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 2),
                                child: ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
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

                  const Divider(thickness: 1),
                  
                  // EXIBIÇÃO DO TOTAL
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("TOTAL:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(
                        "R\$ ${totalPedido.toStringAsFixed(2)}",
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // SELEÇÃO DE PAGAMENTO
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ["Dinheiro", "Pix", "Cartão"].map((forma) {
                      return ChoiceChip(
                        label: Text(forma),
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
                  const SizedBox(height: 10),

                  // BOTÃO PRINCIPAL
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: carrinho.isEmpty ? Colors.grey.shade400 : Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: carrinho.isEmpty ? null : finalizarVenda,
                      child: const Text("FINALIZAR VENDA", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
