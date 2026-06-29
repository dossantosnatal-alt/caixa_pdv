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
      title: 'PDV Multi-Eventos',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: false,
      ),
      home: const TelaIdentificacao(),
    );
  }
}

// =============================================================================
// 1. TELA DE IDENTIFICAÇÃO E SEGURANÇA (ADM vs CAIXA)
// =============================================================================
class TelaIdentificacao extends StatefulWidget {
  const TelaIdentificacao({Key? key}) : super(key: key);

  @override
  _TelaIdentificacaoState createState() => _TelaIdentificacaoState();
}

class _TelaIdentificacaoState extends State<TelaIdentificacao> {
  final TextEditingController _operadorController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  bool _ehAdmin = false;

  String nomeEvento = "Carregando...";
  String periodoEvento = "...";
  String pinAdminValido = "9999"; // Fallback padrão caso falte no banco

  @override
  void initState() {
    super.initState();
    _buscarConfiguracoesEvento();
  }

  void _buscarConfiguracoesEvento() async {
    try {
      var doc = await FirebaseFirestore.instance.collection('configuracoes').doc('evento_atual').get();
      if (doc.exists) {
        setState(() {
          nomeEvento = doc.data()?['nome_evento'] ?? "Evento Geral";
          periodoEvento = doc.data()?['periodo'] ?? "";
          pinAdminValido = doc.data()?['pin_adm'] ?? "9999";
        });
      } else {
        // Inicializa nó padrão caso não exista no Firestore
        await FirebaseFirestore.instance.collection('configuracoes').doc('evento_atual').set({
          'nome_evento': 'Dia Com Maria',
          'periodo': 'Junho 2026',
          'pin_adm': '1234'
        });
        _buscarConfiguracoesEvento();
      }
    } catch (e) {
      setState(() {
        nomeEvento = "Modo Offline Local";
      });
    }
  }

  void _entrarNoApp() {
    final String nome = _operadorController.text.trim();
    final String pinInserido = _pinController.text.trim();

    if (_ehAdmin) {
      if (pinInserido == pinAdminValido) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => TelaPainelAdmin(nomeEvento: nomeEvento)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN Administrativo incorreto!'), backgroundColor: Colors.red),
        );
      }
    } else {
      if (nome.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informe o nome do operador/caixa.'), backgroundColor: Colors.orange),
        );
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => TelaCaixa(
            nomeOperador: nome,
            nomeEvento: nomeEvento,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo.shade50,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 6,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.layers, size: 54, color: Colors.indigo.shade700),
                  const SizedBox(height: 12),
                  Text(
                    nomeEvento,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  if (periodoEvento.isNotEmpty)
                    Text(periodoEvento, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                  const Divider(height: 32),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ChoiceChip(
                        label: const Text("Operador de Caixa"),
                        selected: !_ehAdmin,
                        onSelected: (val) => setState(() => _ehAdmin = !val),
                      ),
                      const SizedBox(width: 12),
                      ChoiceChip(
                        label: const Text("Administrador"),
                        selected: _ehAdmin,
                        onSelected: (val) => setState(() => _ehAdmin = val),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (!_ehAdmin)
                    TextField(
                      controller: _operadorController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: "Identificação do Caixa (Ex: Natal, Caixa 1)",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                  if (_ehAdmin)
                    TextField(
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: "PIN de Acesso ADM",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                      ),
                    ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _entrarNoApp,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.shade700),
                      child: Text(_ehAdmin ? "ACESSAR PAINEL ADM" : "ABRIR FRENTE DE CAIXA"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 2. FRENTE DE CAIXA (PRODUTOS DINÂMICOS DO FIRESTORE)
// =============================================================================
class TelaCaixa extends StatefulWidget {
  final String nomeOperador;
  final String nomeEvento;
  const TelaCaixa({Key? key, required this.nomeOperador, required this.nomeEvento}) : super(key: key);

  @override
  _TelaCaixaState createState() => _TelaCaixaState();
}

class _TelaCaixaState extends State<TelaCaixa> {
  List<Map<String, dynamic>> carrinho = [];
  String formaPagamento = "Dinheiro";
  double acumuladoVendasLocal = 0.0;
  double acumuladoSangriasLocal = 0.0;

  final TextEditingController _sangriaController = TextEditingController();

  double get totalPedido => carrinho.fold(0, (sum, item) => sum + (item['preco'] * item['quantidade']));

  void finalizarVenda() async {
    if (carrinho.isEmpty) return;
    final double valorVendaAtual = totalPedido;

    setState(() {
      acumuladoVendasLocal += valorVendaAtual;
    });

    try {
      final dadosVenda = {
        "caixa": widget.nomeOperador,
        "evento": widget.nomeEvento,
        "data_hora": FieldValue.serverTimestamp(),
        "forma_pagamento": formaPagamento,
        "total": valorVendaAtual,
        "tipo": "venda",
        "itens": carrinho.map((item) => {
          "nome": item['nome'],
          "preco_unitario": item['preco'],
          "quantidade": item['quantidade'],
          "subtotal": item['preco'] * item['quantidade']
        }).toList(),
      };

      FirebaseFirestore.instance.collection('vendas').add(dadosVenda);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Venda registrada com sucesso!'), backgroundColor: Colors.green),
      );

      setState(() {
        carrinho.clear();
        formaPagamento = "Dinheiro";
      });
    } catch (e) {
      print("Erro ao subir venda: $e");
    }
  }

  void registrarSangria() async {
    final double? valor = double.tryParse(_sangriaController.text.replaceFirst(',', '.'));
    if (valor == null || valor <= 0) return;

    setState(() => acumuladoSangriasLocal += valor);

    try {
      FirebaseFirestore.instance.collection('vendas').add({
        "caixa": widget.nomeOperador,
        "evento": widget.nomeEvento,
        "data_hora": FieldValue.serverTimestamp(),
        "forma_pagamento": "Dinheiro",
        "total": valor,
        "tipo": "sangria",
        "itens": []
      });

      _sangriaController.clear();
      Navigator.of(context).pop();
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.nomeEvento} - Caixa"),
        backgroundColor: Colors.indigo.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.money_off),
            tooltip: "Sangria",
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Registrar Sangria"),
                  content: TextField(
                    controller: _sangriaController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Valor (R\$)"),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
                    ElevatedButton(onPressed: registrarSangria, child: const Text("CONFIRMAR")),
                  ],
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const TelaIdentificacao()),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // PAINEL LOCAL (Segurança: Caixa só visualiza o próprio turno atual)
              Card(
                color: Colors.indigo.shade900,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Operador: ${widget.nomeOperador}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          const Icon(Icons.lock_outline, color: Colors.white70, size: 16),
                        ],
                      ),
                      const Divider(color: Colors.white24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Text("Vendas: R\$ ${acumuladoVendasLocal.toStringAsFixed(2)}", style: const TextStyle(color: Colors.greenAccent)),
                          Text("Sangrias: R\$ ${acumuladoSangriasLocal.toStringAsFixed(2)}", style: const TextStyle(color: Colors.redAccent)),
                          Text("Saldo: R\$ ${(acumuladoVendasLocal - acumuladoSangriasLocal).toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              // CARREGAMENTO DINÂMICO DOS PRODUTOS CADASTRADOS NO FIRESTORE
              const Text("Cardápio", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance.collection('produtos').where('ativo', isEqualTo: true).get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  var docs = snapshot.data!.docs;
                  if (docs.isEmpty) return const Text("Nenhum produto cadastrado no painel.");

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, childAspectRatio: 1.2, crossAxisSpacing: 6, mainAxisSpacing: 6,
                    ),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      var prodData = docs[index].data() as Map<String, dynamic>;
                      return ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.shade50, foregroundColor: Colors.indigo.shade900),
                        onPressed: () {
                          setState(() {
                            final idx = carrinho.indexWhere((item) => item['nome'] == prodData['nome']);
                            if (idx >= 0) {
                              carrinho[idx]['quantidade']++;
                            } else {
                              carrinho.add({"nome": prodData['nome'], "preco": (prodData['preco'] as num).toDouble(), "quantidade": 1});
                            }
                          });
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(prodData['nome'], textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            Text("R\$ ${prodData['preco'].toStringAsFixed(2)}", style: const TextStyle(fontSize: 11, color: Colors.green)),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
              
              // CARRINHO E PAGAMENTO
              const SizedBox(height: 16),
              const Divider(thickness: 1.5),
              Container(
                height: 120,
                color: Colors.grey.shade50,
                child: ListView.builder(
                  itemCount: carrinho.length,
                  itemBuilder: (context, index) {
                    final item = carrinho[index];
                    return ListTile(
                      title: Text("${item['nome']} (x${item['quantidade']})"),
                      trailing: Text("R\$ ${(item['preco'] * item['quantidade']).toStringAsFixed(2)}"),
                      leading: IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () => setState(() => item['quantidade'] > 1 ? item['quantidade']-- : carrinho.removeAt(index)),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("TOTAL:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text("R\$ ${totalPedido.toStringAsFixed(2)}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
              ),
              DropdownButton<String>(
                value: formaPagamento,
                isExpanded: true,
                items: ["Dinheiro", "Pix", "Cartão"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (val) => setState(() => formaPagamento = val!),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: carrinho.isEmpty ? null : finalizarVenda,
                  child: const Text("FINALIZAR VENDA", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 3. PAINEL ADMINISTRATIVO (CADASTROS E VISUALIZAÇÃO GLOBAL DE ACESSOS)
// =============================================================================
class TelaPainelAdmin extends StatefulWidget {
  final String nomeEvento;
  const TelaPainelAdmin({Key? key, required this.nomeEvento}) : super(key: key);

  @override
  _TelaPainelAdminState createState() => _TelaPainelAdminState();
}

class _TelaPainelAdminState extends State<TelaPainelAdmin> {
  final TextEditingController _nomeProdController = TextEditingController();
  final TextEditingController _precoProdController = TextEditingController();

  void _adicionarProduto() async {
    if (_nomeProdController.text.trim().isEmpty || _precoProdController.text.trim().isEmpty) return;
    double? preco = double.tryParse(_precoProdController.text.replaceFirst(',', '.'));
    if (preco == null) return;

    await FirebaseFirestore.instance.collection('produtos').add({
      'nome': _nomeProdController.text.trim(),
      'preco': preco,
      'ativo': true,
    });

    _nomeProdController.clear();
    _precoProdController.clear();
    Navigator.pop(context);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Painel Executivo ADM"),
          backgroundColor: Colors.indigo.shade800,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.analytics), text: "Movimentação Global"),
              Tab(icon: Icon(Icons.restaurant_menu), text: "Gerenciar Cardápio"),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const TelaIdentificacao()),
              ),
            )
          ],
        ),
        body: TabBarView(
          children: [
            // ABA 1: SEGURANÇA TOTAL - ADM VÊ O MOVIMENTO DE TODOS OS CAIXAS ONLINE
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('vendas').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  
                  double globalVendas = 0;
                  double globalSangrias = 0;
                  Map<String, double> resumoPorCaixa = {};

                  for (var doc in snapshot.data!.docs) {
                    var d = doc.data() as Map<String, dynamic>;
                    double total = (d['total'] as num?)?.toDouble() ?? 0.0;
                    String tipo = d['tipo'] ?? 'venda';
                    String caixa = d['caixa'] ?? 'Desconhecido';

                    if (tipo == 'sangria') {
                      globalSangrias += total;
                      resumoPorCaixa[caixa] = (resumoPorCaixa[caixa] ?? 0.0) - total;
                    } else {
                      globalVendas += total;
                      resumoPorCaixa[caixa] = (resumoPorCaixa[caixa] ?? 0.0) + total;
                    }
                  }

                  return Column(
                    children: [
                      Card(
                        color: Colors.grey.shade900,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Text("Total Vendas:\nR\$ ${globalVendas.toStringAsFixed(2)}", style: const TextStyle(color: Colors.greenAccent)),
                              Text("Total Sangrias:\nR\$ ${globalSangrias.toStringAsFixed(2)}", style: const TextStyle(color: Colors.redAccent)),
                              Text("Saldo Geral:\nR\$ ${(globalVendas - globalSangrias).toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text("Posição por Operador de Caixa:", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView(
                          children: resumoPorCaixa.entries.map((e) => ListTile(
                            leading: const Icon(Icons.person),
                            title: Text(e.key),
                            trailing: Text("R\$ ${e.value.toStringAsFixed(2)}", style: TextStyle(color: e.value >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                          )).toList(),
                        ),
                      )
                    ],
                  );
                },
              ),
            ),
            
            // ABA 2: CADASTRO E GERENCIAMENTO DOS PRODUTOS (SEM MEXER EM CÓDIGO)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text("Novo Item no Cardápio"),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(controller: _nomeProdController, decoration: const InputDecoration(labelText: "Nome do Produto")),
                              TextField(controller: _precoProdController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Preço de Venda (R\$)")),
                            ],
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
                            ElevatedButton(onPressed: _adicionarProduto, child: const Text("SALVAR NOVO PRODUTO")),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text("ADICIONAR PRODUTO AO CARDÁPIO"),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: FutureBuilder<QuerySnapshot>(
                      future: FirebaseFirestore.instance.collection('produtos').get(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                        var docs = snapshot.data!.docs;
                        return ListView.builder(
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            var id = docs[index].id;
                            var p = docs[index].data() as Map<String, dynamic>;
                            bool ativo = p['ativo'] ?? true;

                            return ListTile(
                              title: Text(p['nome']),
                              subtitle: Text("R\$ ${(p['preco'] as num).toStringAsFixed(2)}"),
                              trailing: Switch(
                                value: ativo,
                                onChanged: (val) async {
                                  await FirebaseFirestore.instance.collection('produtos').doc(id).update({'ativo': val});
                                  setState(() {});
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
