import 'package:flutter/material.dart';
import 'package:kurshachtt/screen/reel/signup_screen.dart';
import 'package:kurshachtt/screen/reel/web_reel_admin_screen.dart';
import 'package:kurshachtt/screen/home/tiktok_home_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/text_input_field.dart';
import 'admin_reel_screen.dart';

class LoginScreen extends StatelessWidget {
  LoginScreen({Key? key}) : super(key: key);

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();



  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth > 600 ? screenWidth * 0.3 : 50.0;

    return Scaffold(
      backgroundColor: Color(0xFF070707),
      body: Container(
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Tiktok',
              style: TextStyle(
                fontSize: 35,
                color: Color(0xFFCA1010),
                fontWeight: FontWeight.w900,
              ),
            ),
            const Text(
              'Вход',
              style: TextStyle(
color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 25),
            Container(
              width: MediaQuery.of(context).size.width,
              margin: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: TextInputField(
                controller: _emailController,
                labelText: 'Email',
                icon: Icons.email,

              ),
            ),
            const SizedBox(height: 25),
            Container(
              width: MediaQuery.of(context).size.width,
              margin: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: TextInputField(
                controller: _passwordController,
                labelText: 'Пароль',
                icon: Icons.lock,
                isObscure: true,
              ),
            ),
            const SizedBox(height: 30),
            Container(
              margin: EdgeInsets.symmetric(horizontal: horizontalPadding),
              height: 50,
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: const BorderRadius.all(Radius.circular(5)),
              ),
              child: InkWell(
                onTap: () async {
                  final email = _emailController.text.trim();
                  final password = _passwordController.text.trim();

                  if (email.isEmpty || password.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Поля не могут быть пустыми'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  try {
                    final response = await Supabase.instance.client.auth.signInWithPassword(
                      email: email,
                      password: password,
                    );

                    if (response.user != null) {
                      final userId = response.user!.id;

                      final userData = await Supabase.instance.client
                          .from('user')
                          .select('role')
                          .eq('id', userId)
                          .single();

                      final userRole = userData['role'];

                      if (userRole == 'admin') {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => WebAdminReelScreen(currentUserId: userId)),
                        );
                      } else {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => TiktokHomeScreen(userId: userId)),
                        );
                      }
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Неверный логин или пароль'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: const Center(
                  child: Text(
                    'Войти',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Нет аккаунта?  ',
                  style: TextStyle(fontSize: 20, color: Colors.white),
                ),
                InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => SignupScreen(),
                    ),
                  ),
                  child: Text(
                    'Зарегистрироваться',
                    style: TextStyle(fontSize: 20, color: Colors.red),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
