import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ItemCarrinho {
  final String id;
  final String nome;
  final double preco;
  int quantidade;

  ItemCarrinho({
    required this.id,
    required this.nome,
    required this.preco,
    this.quantidade = 1,
  });
}

class TelaPDV extends StatefulWidget {
  final String caixaId;

  const TelaPDV({super.key, required this.caixaId});

  @override
  State<TelaPDV> createState() => _TelaPDVState();
}

class _TelaPDVState extends State<TelaPDV> {
  final List<ItemCarrinho> _carrinho = [];

  double get _totalGeral => _carrinho.fold(0.0, (sum, item) => sum + (item.preco * item.quantidade));

  void _adicionarAoCarrinho(String id, String nome, double preco) {
    setState(() {
      final index = _carrinho.indexWhere((item) => item.id == id);
      if (index >= 0) {
        _carrinho[index].quantidade++;
      } else {
        _carrinho.add(ItemCarrinho(id: id, nome: nome, preco: preco));
      }
    });
  }

  void _alterarQuantidade(int index, int mudanca) {
    setState(() {
      _carrinho[index].quantidade += mudanca;
      if (_carrinho[index].quantidade <= 0) {
        _carrinho.removeAt(index);
      }
    });
  }

  void _abrirModalPagamento() {
    if (_carrinho.isEmpty) {
      _mostrarMensagem('O carrinho está vazio!', Colors.orange);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Escolha a Forma de Pagamento'),
        content: Text(
          'Total da Venda: R\$ ${_totalGeral.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Voltar'),
          ),
          const Divider(),
          _botaoPagamento(context, 'Dinheiro', 'vendas_dinheiro'),
          _botaoPagamento(context, 'PIX', 'vendas_pix'),
          _botaoPagamento(context, 'Débito', 'vendas_debito'),
          _botaoPagamento(context, 'Crédito', 'vendas_credito'),
        ],
      ),
    );
  }

  Widget _botaoPagamento(BuildContext dialogContext, String label, String campoCaixa) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onPressed: () => _processarVenda(dialogContext, label, campoCaixa),
        child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<void> _processarVenda(BuildContext dialogContext, String formaPagamento, String campoCaixa) async {
    Navigator.pop(dialogContext);
    
    final double valorVenda = _totalGeral;
    final List<ItemCarrinho> itensProcessando = List.from(_carrinho);
    
    setState(() {
      _carrinho.clear();
    });

    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    try {
      for (var item in itensProcessando) {
        final prodRef = firestore.collection('produtos').doc(item.id);
        batch.update(prodRef, {
          'estoque': FieldValue.increment(-item.quantidade),
        });
      }

      final caixaRef = firestore.collection('caixas').doc(widget.caixaId);
      batch.update(caixaRef, {
        campoCaixa: FieldValue.increment(valorVenda),
      });

      final vendaNovaRef = firestore.collection('vendas').doc();
      batch.set(vendaNovaRef, {
        'caixa_id': widget.caixaId,
        'data_hora': FieldValue.serverTimestamp(),
        'total': valorVenda,
        'forma_pagamento': formaPagamento,
        'itens': itensProcessando.map((i) => {
          'id': i.id,
          'nome': i.nome,
          'preco': i.preco,
          'quantidade': i.quantidade
        }).toList(),
      });

      await batch.commit();
      _mostrarMensagem('Venda em $formaPagamento realizada com sucesso!', Colors.green);
    } catch (e) {
      _mostrarMensagem('Ocorreu um erro ao salvar a venda: $e', Colors.red);
    }
  }

  void _mostrarMensagem(String texto, Color cor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), backgroundColor: cor, duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Caixa Livre - Tela de Vendas'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Se a tela for larga (Web/Tablet), coloca carrinho na lateral direita
          // Se for estreita (Celular), coloca o carrinho embaixo
          bool telaLarga = constraints.maxWidth > 700;

          Widget secaoProdutos = StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('produtos').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('Nenhum produto encontrado.'));
              }

              final produtos = snapshot.data!.docs;

              return GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: telaLarga ? 4 : 2, // 4 colunas na web, 2 no celular
                  childAspectRatio: 1.9, // Formato mais quadrado e equilibrado
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: produtos.length,
                itemBuilder: (context, index) {
                  var prodData = produtos[index].data() as Map<String, dynamic>;
                  String id = produtos[index].id;
                  String nome = prodData['nome'] ?? 'Sem nome';
                  
                  // Garantindo que tipos numéricos do Firestore sejam lidos corretamente
                  double preco = 0.0;
                  if (prodData['preco'] != null) {
                    preco = (prodData['preco'] is int) 
                        ? (prodData['preco'] as int).toDouble() 
                        : (prodData['preco'] as double);
                  }

                  int estoque = 0;
                  if (prodData['estoque'] != null) {
                    estoque = (prodData['estoque'] as num).toInt();
                  }

                  bool temEstoque = estoque > 0;

                  return Card(
                    clipBehavior: Clip.antiAlias,
                    color: temEstoque ? Colors.white : Colors.grey.shade200,
                    elevation: 3,
                    child: InkWell(
                      onTap: temEstoque ? () => _adicionarAoCarrinho(id, nome, preco) : null,
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nome,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: temEstoque ? Colors.black87 : Colors.grey,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Spacer(),
                            Text(
                              'R\$ ${preco.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 16, 
                                color: temEstoque ? Colors.green.shade700 : Colors.grey, 
                                fontWeight: FontWeight.bold
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              temEstoque ? 'Estoque: $estoque' : 'Esgotado',
                              style: TextStyle(
                                fontSize: 12,
                                color: temEstoque ? Colors.blueGrey : Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );

          Widget secaoCarrinho = Container(
            color: Colors.grey.shade50,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(Icons.shopping_basket, color: Colors.indigo),
                    SizedBox(width: 8),
                    Text('Carrinho Atual', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _carrinho.isEmpty
                      ? const Center(child: Text('Selecione os produtos', style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          itemCount: _carrinho.length,
                          itemBuilder: (context, index) {
                            final item = _carrinho[index];
                            return Card(
                              elevation: 1,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                dense: true,
                                title: Text(item.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('un: R\$ ${item.preco.toStringAsFixed(2)} | Total: R\$ ${(item.preco * item.quantidade).toStringAsFixed(2)}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                      onPressed: () => _alterarQuantidade(index, -1),
                                    ),
                                    Text('${item.quantidade}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                                      onPressed: () => _adicionarAoCarrinho(item.id, item.nome, item.preco),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TOTAL:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(
                        'R\$ ${_totalGeral.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _carrinho.isEmpty ? null : _abrirModalPagamento,
                  child: const Text('FINALIZAR VENDA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );

          // Retorno Responsivo Inteligente
          if (telaLarga) {
            return Row(
              children: [
                Expanded(flex: 3, child: secaoProdutos),
                VerticalDivider(width: 1, color: Colors.grey.shade300),
                SizedBox(width: 380, child: secaoCarrinho),
              ],
            );
          } else {
            return Column(
              children: [
                Expanded(flex: 3, child: secaoProdutos),
                Divider(height: 1, color: Colors.grey.shade300),
                Expanded(flex: 2, child: secaoCarrinho),
              ],
            );
          }
        },
      ),
    );
  }
}
