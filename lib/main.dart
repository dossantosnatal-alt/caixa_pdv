import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'telas/login.dart';
import 'telas/painel_caixa.dart';
import 'telas/pdv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print("Erro ao inicializar o Firebase: $e");
  }
  
  runApp(const MeuApp());
}

class MeuApp extends StatelessWidget {
  const MeuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Caixa PDV',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const TelaLogin(),
      
      // Rotas corrigidas para os construtores reais do seu projeto
      onGenerateRoute: (settings) {
        if (settings.name == '/caixa') {
          return MaterialPageRoute(
            builder: (context) => const TelaPainelCaixa(),
          );
        }
        
        if (settings.name == '/pdv') {
          // Captura o ID do caixa passado como argumento, ou usa um padrão se vier vazio
          final args = settings.arguments as String? ?? 'padrão';
          return MaterialPageRoute(
            builder: (context) => TelaPDV(caixaId: args),
          );
        }
        
        return null;
      },
      
      routes: {
        '/login': (context) => const TelaLogin(),
      },
    );
  }
}
