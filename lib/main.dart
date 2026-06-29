import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Controle de Caixa - Dia Com Maria',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: false,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            return TelaCaixa();
          }
          return TelaLogin();
        },
      ),
    );
  }
}

// --- TELA DE LOGIN ---
class TelaLogin extends StatefulWidget {
  TelaLogin({Key? key}) : super(key: key);

  @override
  _TelaLoginState createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  bool _carregando = false;

  void _fazerLogin() async {
    setState(() => _carregando = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _senhaController.text.trim(),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro ao acessar: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.account_balance_wallet, size: 64, color: Colors.blue.shade700),
                  const SizedBox(height: 16),
                  const Text(
                    "Controle de Caixa\nDia Com Maria",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: "E-mail cadastrado",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _senhaController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Senha",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _carregando ? null : _fazerLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _carregando
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("ENTRAR", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

// --- TELA DO CAIXA ---
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

    final User? usuarioAtual = FirebaseAuth.instance.currentUser;
    final String emailOperador = usuarioAtual?.email ?? "Desconhecido";

    try {
      final dadosVenda = {
        "caixa": emailOperador,
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
    final User? usuarioAtual = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Controle de Caixa - Dia Com Maria"),
        backgroundColor: Colors.blue.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Sair do Caixa",
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Operador: ${usuarioAtual?.email ?? ''}",
                style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500, fontSize: 13),
              ),
              const SizedBox(height: 8),
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
              const SizedBox(height: 8),
              
              // Substituído o ChoiceChip por botões manuais infalíveis e limpos
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: ["Dinheiro", "Pix", "Cartão"].map((forma) {
                  bool selecionado = formaPagamento == forma;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selecionado ? Colors.blue.shade700 : Colors.grey.shade200,
                          foregroundColor: selecionado ? Colors.white : Colors.black87,
                          elevation: selecionado ? 2 : 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          setState(() {
                            formaPagamento = forma;
                          });
                        },
                        child: Text(forma, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
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
