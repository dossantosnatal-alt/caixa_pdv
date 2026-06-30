import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Modelo simples para controlar o carrinho localmente nesta tela
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
  final String caixaId; // Recebe o ID do caixa aberto para acumular as vendas

  const TelaPDV({super.key, required this.caixaId});

  @override
  State<TelaPDV> createState() => _TelaPDVState();
}

class _TelaPDVState extends State<TelaPDV> {
  final List<ItemCarrinho> _carrinho = [];

  // Calcula o valor total atual do carrinho
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

  // CORRIGIDO: Removido caractere especial 'ç' do parâmetro
  void _alterarQuantidade(int index, int mudanca) {
    setState(() {
      _carrinho[index].quantidade += mudanca;
      if (_carrinho[index].quantidade <= 0) {
        _carrinho.removeAt(index);
      }
    });
  }

  // Abre a caixa de diálogo para escolher a forma de pagamento e encerrar a venda
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

  // Executa a baixa de estoque e envia o faturamento para o caixa ativo
  Future<void> _processarVenda(BuildContext dialogContext, String formaPagamento, String campoCaixa) async {
    Navigator.pop(dialogContext); // Fecha o modal de pagamento de imediato
    
    // Armazena o valor a ser processado e limpa o carrinho na UI para dar feedback rápido de clique único
    final double valorVenda = _totalGeral;
    final List<ItemCarrinho> itensProcessando = List.from(_carrinho);
    
    setState(() {
      _carrinho.clear();
    });

    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    try {
      // 1. Atualiza o estoque de cada produto vendido no lote (Batch)
      for (var item in itensProcessando) {
        final prodRef = firestore.collection('produtos').doc(item.id);
        batch.update(prodRef, {
          'estoque': FieldValue.increment(-item.quantidade),
        });
      }

      // 2. Acumula os valores faturados dentro do Caixa Diário do operador
      final caixaRef = firestore.collection('caixas').doc(widget.caixaId);
      batch.update(caixaRef, {
        campoCaixa: FieldValue.increment(valorVenda),
      });

      // 3. Salva o registro histórico da venda independente
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

      // Executa de forma atômica no servidor
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
      body: Row(
        children: [
          // LADO ESQUERDO: Grade de seleção de produtos da loja
          Expanded(
            flex: 3,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('produtos').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Nenhum produto em estoque encontrado.'));
                }

                final produtos = snapshot.data!.docs;

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: produtos.length,
                  itemBuilder: (context, index) {
                    var prodData = produtos[index].data() as Map<String, dynamic>;
                    String id = produtos[index].id;
                    String nome = prodData['nome'] ?? 'Sem nome';
                    double preco = (prodData['preco'] ?? 0.0).toDouble();
                    int estoque = (prodData['estoque'] ?? 0).toInt();

                    bool temEstoque = estoque > 0;

                    return Card(
                      color: temEstoque ? Colors.white : Colors.grey.shade200,
                      elevation: 3,
                      child: InkWell(
                        onTap: temEstoque ? () => _adicionarAoCarrinho(id, nome, preco) : null,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                nome,
                                style: TextStyle(
                                  fontSize: 16, 
                                  fontWeight: FontWeight.bold,
                                  color: temEstoque ? Colors.black : Colors.grey,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Spacer(),
                              Text(
                                'R\$ ${preco.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 18, color: Colors.green, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                temEstoque ? 'Disponível: $estoque' : 'Esgotado',
                                style: TextStyle(
                                  fontSize: 12, 
                                  color: temEstoque ? Colors.grey.shade600 : Colors.red,
                                  fontWeight: FontWeight.bold
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // DIVISÓRIA VISUAL
          VerticalDivider(width: 1, color: Colors.grey.shade400),

          // LADO DIREITO: Carrinho Operacional com Checkout
          Container(
            width: 400,
            color: Colors.grey.shade50,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(Icons.shopping_basket, color: Colors.indigo),
                    SizedBox(width: 8),
                    Text('Carrinho Atual', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Lista de Itens Comprados
                Expanded(
                  child: _carrinho.isEmpty
                      ? const Center(child: Text('Selecione produtos ao lado', style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          itemCount: _carrinho.length,
                          itemBuilder: (context, index) {
                            final item = _carrinho[index];
                            return Card(
                              elevation: 1,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                title: Text(item.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text('un: R\$ ${item.preco.toStringAsFixed(2)} | Sub: R\$ ${(item.preco * item.quantidade).toStringAsFixed(2)}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                      onPressed: () => _alterarQuantidade(index, -1),
                                    ),
                                    Text('${item.quantidade}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                                      onPressed: () => _alterarQuantidade(index, 1),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const Divider(),

                // Painel de Total e Fechamento de Cupom
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TOTAL:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text(
                        'R\$ ${_totalGeral.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.indigo),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('FINALIZAR VENDA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _carrinho.isEmpty ? null : _abrirModalPagamento,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
