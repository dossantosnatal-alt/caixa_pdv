import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pdv.dart'; // Tela de Vendas única

class TelaPainelCaixa extends StatefulWidget {
  const TelaPainelCaixa({super.key});

  @override
  State<TelaPainelCaixa> createState() => _TelaPainelCaixaState();
}

class _TelaPainelCaixaState extends State<TelaPainelCaixa> {
  String? _operadorEmail;
  bool _carregando = true;
  DocumentSnapshot? _caixaAtualDoc;

  // Controllers para os Inputs
  final _saldoInicialController = TextEditingController();
  final _sangriaController = TextEditingController();
  final _sangriaMotivoController = TextEditingController();
  final _dinheiroGavetaController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_operadorEmail == null) {
      // Recupera o e-mail enviado pela tela de login
      _operadorEmail = ModalRoute.of(context)!.settings.arguments as String?;
      _verificarStatusCaixa();
    }
  }

  // Verifica no Firestore se existe um caixa aberto para este operador
  Future<void> _verificarStatusCaixa() async {
    setState(() => _carregando = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('caixas')
          .where('operador_email', isEqualTo: _operadorEmail)
          .where('status', isEqualTo: 'aberto')
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        _caixaAtualDoc = snapshot.docs.first;
      } else {
        _caixaAtualDoc = null;
      }
    } catch (e) {
      _mostrarMensagem('Erro ao verificar caixa: $e', Colors.red);
    } finally {
      setState(() => _carregando = false);
    }
  }

  // Abertura do Caixa informando o saldo inicial
  Future<void> _abrirCaixa() async {
    final valor = double.tryParse(_saldoInicialController.text.trim()) ?? -1;
    if (valor < 0) {
      _mostrarMensagem('Informe um saldo inicial válido.', Colors.orange);
      return;
    }

    setState(() => _carregando = true);
    try {
      await FirebaseFirestore.instance.collection('caixas').add({
        'operador_email': _operadorEmail,
        'status': 'aberto',
        'saldo_inicial': valor,
        'data_abertura': FieldValue.serverTimestamp(),
        'sangrias': [],
        'vendas_dinheiro': 0.0,
        'vendas_pix': 0.0,
        'vendas_debito': 0.0,
        'vendas_credito': 0.0,
      });
      _saldoInicialController.clear();
      await _verificarStatusCaixa();
    } catch (e) {
      _mostrarMensagem('Erro ao abrir o caixa: $e', Colors.red);
      setState(() => _carregando = false);
    }
  }

  // Realiza a retirada de dinheiro (Sangria)
  Future<void> _realizarSangria() async {
    final valor = double.tryParse(_sangriaController.text.trim()) ?? 0;
    final motivo = _sangriaMotivoController.text.trim();

    if (valor <= 0 || motivo.isEmpty) {
      _mostrarMensagem('Preencha o valor e o motivo da sangria.', Colors.orange);
      return;
    }

    try {
      await _caixaAtualDoc!.reference.update({
        'sangrias': FieldValue.arrayUnion([
          {'valor': valor, 'motivo': motivo, 'data': DateTime.now().toIso8601String()}
        ])
      });
      _sangriaController.clear();
      _sangriaMotivoController.clear();
      Navigator.pop(context); // Fecha o dialog
      await _verificarStatusCaixa();
      _mostrarMensagem('Sangria realizada com sucesso!', Colors.green);
    } catch (e) {
      _mostrarMensagem('Erro ao realizar sangria: $e', Colors.red);
    }
  }

  // Consolida os valores e fecha o caixa
  Future<void> _fecharCaixa(double saldoCalculadoDinheiro) async {
    final dinheiroInformado = double.tryParse(_dinheiroGavetaController.text.trim()) ?? -1;
    if (dinheiroInformado < 0) {
      _mostrarMensagem('Informe o valor físico em dinheiro.', Colors.orange);
      return;
    }

    try {
      await _caixaAtualDoc!.reference.update({
        'status': 'fechado',
        'data_fechamento': FieldValue.serverTimestamp(),
        'dinheiro_em_gaveta_informado': dinheiroInformado,
        'saldo_dinheiro_calculado': saldoCalculadoDinheiro,
        'diferenca_caixa': dinheiroInformado - saldoCalculadoDinheiro,
      });
      _dinheiroGavetaController.clear();
      Navigator.pop(context); // Fecha o modal
      await _verificarStatusCaixa();
      _mostrarMensagem('Caixa fechado com sucesso!', Colors.green);
    } catch (e) {
      _mostrarMensagem('Erro ao fechar o caixa: $e', Colors.red);
    }
  }

  void _mostrarMensagem(String texto, Color cor) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto), backgroundColor: cor));
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_caixaAtualDoc == null) {
      return _buildTelaAbertura();
    }

    final dados = _caixaAtualDoc!.data() as Map<String, dynamic>;
    double saldoInicial = (dados['saldo_inicial'] ?? 0.0).toDouble();
    double vDinheiro = (dados['vendas_dinheiro'] ?? 0.0).toDouble();
    double vPix = (dados['vendas_pix'] ?? 0.0).toDouble();
    double vDebito = (dados['vendas_debito'] ?? 0.0).toDouble();
    double vCredito = (dados['vendas_credito'] ?? 0.0).toDouble();

    List sangriasLista = dados['sangrias'] ?? [];
    double totalSangrias = sangriasLista.fold(0.0, (sum, item) => sum + (item['valor'] ?? 0.0));

    // LÓGICA: Saldo Inicial - Sangrias + Vendas em Dinheiro
    double saldoCalculadoDinheiro = saldoInicial - totalSangrias + vDinheiro;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel Operacional do Caixa'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
          )
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Operador: $_operadorEmail', style: const TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 16),
              
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  childAspectRatio: 2.5,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    _cardValor('Saldo Inicial (Dinheiro)', saldoInicial, Colors.blue),
                    _cardValor('Total Sangrias/Retiradas', totalSangrias, Colors.red),
                    _cardValor('Vendas em Dinheiro (+)', vDinheiro, Colors.green),
                    _cardValor('Vendas em PIX', vPix, Colors.teal),
                    _cardValor('Vendas em Débito', vDebito, Colors.orange),
                    _cardValor('Vendas em Crédito', vCredito, Colors.purple),
                  ],
                ),
              ),

              // AJUSTADO: Card modificado com Wrap para evitar quebras feias em telas pequenas
              Card(
                color: Colors.amber[50],
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    runAlignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      const Text(
                        'SALDO ESPERADO NA GAVETA (DINHEIRO):',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        'R\$ ${saldoCalculadoDinheiro.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.indigo),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // AJUSTADO: Botões superiores simétricos, com altura idêntica e cantos arredondados padronizados
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 55,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.local_atm),
                        label: const Text('SANGRIA', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        onPressed: () => _abrirModalSangria(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red, 
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 55,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.shopping_cart),
                        label: const Text('VENDAS (PDV)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TelaPDV(caixaId: _caixaAtualDoc!.id),
                            ),
                          ).then((_) => _verificarStatusCaixa());
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green, 
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // AJUSTADO: Botão inferior padronizado na mesma linguagem visual e altura
              SizedBox(
                height: 55,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.lock),
                  label: const Text('FECHAR CAIXA DIÁRIO', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  onPressed: () => _abrirModalFechamento(saldoCalculadoDinheiro),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo, 
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTelaAbertura() {
    return Scaffold(
      appBar: AppBar(title: const Text('Abertura de Caixa'), backgroundColor: Colors.indigo, foregroundColor: Colors.white),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.lock_open, size: 64, color: Colors.indigo),
              const SizedBox(height: 16),
              const Text('O Caixa está Fechado.', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('Informe o valor em dinheiro do fundo ou saldo inicial para iniciar as operações do dia.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              TextField(
                controller: _saldoInicialController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Fundo Inicial (R\$ Dinheiro)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.attach_money)),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _abrirCaixa,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('ABRIR CAIXA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardValor(String titulo, double valor, Color cor) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text('R\$ ${valor.toStringAsFixed(2)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cor)),
          ],
        ),
      ),
    );
  }

  void _abrirModalSangria() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Realizar Sangria (Retirada)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _sangriaController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Valor Retirado (R\$)')),
            TextField(controller: _sangriaMotivoController, decoration: const InputDecoration(labelText: 'Motivo/Destino da Sangria')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(onPressed: _realizarSangria, style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text('Confirmar')),
        ],
      ),
    );
  }

  void _abrirModalFechamento(double saldoCalculadoDinheiro) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferência do Caixa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Saldo esperado em Dinheiro: R\$ ${saldoCalculadoDinheiro.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _dinheiroGavetaController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quanto tem em DINHEIRO na gaveta agora?', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Voltar')),
          ElevatedButton(onPressed: () => _fecharCaixa(saldoCalculadoDinheiro), style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white), child: const Text('Concluir Fechamento')),
        ],
      ),
    );
  }
}
