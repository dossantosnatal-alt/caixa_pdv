import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  // Certifique-se de que o Firebase.initializeApp() esteja sendo chamado no seu main real antes de rodar o app
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Caixa PDV',
      theme: ThemeData(
        primarySwatch: Colors.blue,
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
  // Lista oficial de produtos do evento fixada no código
  final List<Map<String, dynamic>> produtos = [
    {"nome": "Refrigerante", "preco": 8.00},
    {"nome": "Agua sem gas", "preco": 3.00},
    {"nome": "Agua com gas", "preco": 3.50},
    {"nome": "Suco Del Valle", "preco": 8.00},
    {"nome": "Pastel", "preco": 8.00},
    {"nome": "Salgado assado", "preco": 8.00},
  ];

  // Lista dinâmica do carrinho
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
      // Monta os dados da venda para salvar na coleção "vendas" do Firebase
      final dadosVenda = {
        "caixa": "Caixa_01",
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
        const SnackBar(content: Text('Venda finalizada e salva no Firebase!'), backgroundColor: Colors.green),
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
        title: const Text("Frente de Caixa [ Caixa_01 ] - Meliponário São José"),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Row(
        children: [
          // LADO ESQUERDO: Grade de Produtos (Quadrados menores e em 4 colunas)
          Expanded(
            flex: 3, 
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12.0),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,      // 4 colunas deixa os botões mais compactos
                  childAspectRatio: 1.3, // Evita que o texto quebre de forma errada
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
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "R\$ ${prod['preco'].toStringAsFixed(2)}",
                          style: const TextStyle(fontSize: 14, color: Colors.green, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // LADO DIREITO: Painel do Carrinho e Resumo do Pedido (Totalmente Visível)
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(left: BorderSide(color: Colors.grey.shade300, width: 1.5)),
              ),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Itens do Pedido",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Divider(thickness: 1.5),

                  // LISTA DO CARRINHO COM ROLAGEM
                  Expanded(
                    child: carrinho.isEmpty
                        ? const Center(
                            child: Text(
                              "Carrinho vazio",
                              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 16),
                            ),
                          )
                        : ListView.builder(
                            itemCount: carrinho.length,
                            itemBuilder: (context, index) {
                              final item = carrinho[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                  title: Text(
                                    "${item['nome']} (x${item['quantidade']})",
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  trailing: Text(
                                    "R\$ ${(item['preco'] * item['quantidade']).toStringAsFixed(2)}",
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
                                  ),
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

                  const Divider(thickness: 1.5),
                  
                  // Exibição do Valor Total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("TOTAL:", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text(
                        "R\$ ${totalPedido.toStringAsFixed(2)}",
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // Seleção da Forma de Pagamento
                  const Text("Forma de Pagamento:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ["Dinheiro", "Pix", "Cartão"].map((forma) {
                      return ChoiceChip(
                        label: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(forma, style: const TextStyle(fontSize: 13)),
                        ),
                        selected: formaPagamento == forma,
                        selectedColor: Colors.blue.shade600,
                        disabledColor: Colors.grey.shade200,
                        labelStyle: TextStyle(
                          color: formaPagamento == forma ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold
                        ),
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
                  const SizedBox(height: 20),

                  // Botão de Finalizar Venda Estilizado
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: carrinho.isEmpty ? Colors.grey.shade400 : Colors.green.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: carrinho.isEmpty ? null : finalizarVenda,
                      child: const Text(
                        "FINALIZAR VENDA", 
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)
                      ),
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
