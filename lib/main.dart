import 'package:flutter/material.dart';
<<<<<<< HEAD
import 'package:firebase_core/firebase_core.dart';
import 'telas/login.dart';
import 'telas/painel_caixa.dart';

Future<void> main() async {
  // Garante que os bindings do Flutter estejam prontos antes de inicializar o Firebase
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialização do Firebase adequada para o Flutter Web
  // IMPORTANTE: Cole aqui dentro das 'FirebaseOptions' as credenciais exatas do seu projeto Firebase Web
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyB45dQNYdAJ4PydbTlD9G_wyWzxDFJ9LfA",
        authDomain: "caixa---dia-com-maria.firebaseapp.com",
        projectId: "caixa---dia-com-maria",
        storageBucket: "caixa---dia-com-maria.firebasestorage.app",
        messagingSenderId: "1030821394632",
        appId: "1:1030821394632:web:909bbefebeba6da01dcdfd",
      ),
    );
  } catch (e) {
    print("Erro ao inicializar o Firebase: $e");
  }

  runApp(const MeuApp());
}

class MeuApp extends StatelessWidget {
  const MeuApp({super.key});
=======
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
>>>>>>> 5f33b952f513e202af05fcbe9a2199b5687e0803

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
<<<<<<< HEAD
      title: 'Caixa PDV',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true, // Ativa o Material 3 para um visual mais moderno e limpo
      ),
      // O fluxo sempre começa exigindo a autenticação do operador
      initialRoute: '/login',
      routes: {
        '/login': (context) => const TelaLogin(),
        '/caixa': (context) => const TelaPainelCaixa(),
      },
=======
      debugShowCheckedModeBanner: false,
      title: 'PDV Autenticado Dinamico',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: false,
      ),
      home: const TelaIdentificacao(),
    );
  }
}

// =============================================================================
// 1. TELA DE LOGIN E VALIDAÇÃO DE PERFIL VIA FIRESTORE
// =============================================================================
class TelaIdentificacao extends StatefulWidget {
  const TelaIdentificacao({Key? key}) : super(key: key);

  @override
  _TelaIdentificacaoState createState() => _TelaIdentificacaoState();
}

class _TelaIdentificacaoState extends State<TelaIdentificacao> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  bool _carregando = false;

  String nomeEvento = "Carregando...";
  String periodoEvento = "...";

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
        });
      } else {
        setState(() {
          nomeEvento = "Dia Com Maria";
        });
      }
    } catch (e) {
      setState(() {
        nomeEvento = "Modo Conectado";
      });
    }
  }

  void _realizarLogin() async {
    final String email = _emailController.text.trim().toLowerCase();
    final String senha = _senhaController.text.trim();

    if (email.isEmpty || senha.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, preencha e-mail e senha.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _carregando = true);

    try {
      // 1. Autentica o usuário com o Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: senha,
      );

      User? usuarioLogado = userCredential.user;

      if (usuarioLogado != null) {
        // 2. Busca o perfil e o status do usuário na coleção 'usuarios' do Firestore
        var userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(email).get();

        String perfil = 'caixa'; // Perfil padrão caso não esteja configurado
        bool ativo = true;

        if (userDoc.exists) {
          perfil = userDoc.data()?['perfil'] ?? 'caixa';
          ativo = userDoc.data()?['ativo'] ?? true;
        } else {
          // Se o usuário existe no Auth mas não no banco, cria o registro inicial como caixa ativo
          await FirebaseFirestore.instance.collection('usuarios').doc(email).set({
            'perfil': 'caixa',
            'ativo': true,
          });
        }

        // 3. Verifica se o acesso está bloqueado
        if (!ativo) {
          await FirebaseAuth.instance.signOut();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Seu acesso a este evento foi suspenso!'), backgroundColor: Colors.red),
          );
          return;
        }

        // 4. Redireciona com base no perfil vindo do Banco de Dados
        if (perfil == 'admin') {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => TelaPainelAdmin(nomeEvento: nomeEvento)),
          );
        } else {
          String nomeExibicao = email.split('@')[0].toUpperCase();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => TelaCaixa(
                nomeOperador: nomeExibicao,
                nomeEvento: nomeEvento,
              ),
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String mensagemErro = "Erro ao autenticar. Verifique os dados.";
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        mensagemErro = "E-mail ou senha incorretos!";
      } else if (e.code == 'user-disabled') {
        mensagemErro = "Este login foi desativado no Firebase!";
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensagemErro), backgroundColor: Colors.red),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro inesperado: $e"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _carregando = false);
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
                  Icon(Icons.lock_person, size: 54, color: Colors.indigo.shade700),
                  const SizedBox(height: 12),
                  Text(
                    nomeEvento,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  if (periodoEvento.isNotEmpty)
                    Text(periodoEvento, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                  const Divider(height: 32),
                  
                  const Text(
                    "LOGIN RESTRITO",
                    style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),

                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: "E-mail Cadastrado",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _senhaController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Senha de Acesso",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.key),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _carregando ? null : _realizarLogin,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.shade700),
                      child: _carregando 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("ENTRAR NO SISTEMA", style: TextStyle(fontWeight: FontWeight.bold)),
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
// 2. FRENTE DE CAIXA OPERACIONAL (FLEXIBLE ADICIONADO CONTRA TELA CINZA)
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
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const TelaIdentificacao()),
              );
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                        const Icon(Icons.verified_user, color: Colors.greenAccent, size: 16),
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
            const Text("Cardápio", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            
            Flexible(
              flex: 3,
              child: FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance.collection('produtos').where('ativo', isEqualTo: true).get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  var docs = snapshot.data!.docs;
                  if (docs.isEmpty) return const Text("Nenhum produto ativo cadastrado.");

                  return GridView.builder(
                    shrinkWrap: true,
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
            ),
            
            const SizedBox(height: 12),
            const Divider(thickness: 1.5),
            
            Flexible(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: carrinho.length,
                  itemBuilder: (context, index) {
                    final item = carrinho[index];
                    return ListTile(
                      dense: true,
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
                    );
                  },
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("TOTAL:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text("R\$ ${totalPedido.toStringAsFixed(2)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              ),
            ),
            DropdownButton<String>(
              value: formaPagamento,
              isExpanded: true,
              items: ["Dinheiro", "Pix", "Cartão"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (val) => setState(() => formaPagamento = val!),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: carrinho.isEmpty ? null : finalizarVenda,
                child: const Text("FINALIZAR VENDA", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 3. PAINEL ADMINISTRATIVO GENERALIZADO (ESTÁVEL CONTRA ESTOURO)
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
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const TelaIdentificacao()),
                );
              },
            )
          ],
        ),
        body: TabBarView(
          children: [
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
>>>>>>> 5f33b952f513e202af05fcbe9a2199b5687e0803
    );
  }
}
