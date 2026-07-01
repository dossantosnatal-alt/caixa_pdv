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
      
      // Gerador de rotas corrigido para repassar os argumentos (settings)
      onGenerateRoute: (settings) {
        if (settings.name == '/caixa') {
          return MaterialPageRoute(
            builder: (context) => const TelaPainelCaixa(),
            settings: settings, // <-- CORREÇÃO: Encaminha os argumentos do Login para o Painel
          );
        }
        
        if (settings.name == '/pdv') {
          final args = settings.arguments as String? ?? 'padrão';
          return MaterialPageRoute(
            builder: (context) => TelaPDV(caixaId: args),
            settings: settings, // <-- Mantém a consistência de navegação
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
