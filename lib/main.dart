import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
    );
  }
}
