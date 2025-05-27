import 'dart:io';
import 'package:flutter/material.dart';
import 'package:kurshachtt/screen/reel/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'package:bcrypt/bcrypt.dart';
import '../../widgets/text_input_field.dart';
import 'package:path_provider/path_provider.dart';

class SignupScreen extends StatelessWidget {
  SignupScreen({Key? key}) : super(key: key);

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  bool _isPasswordValid(String password) {
    return password.length >= 6 &&
        password.length <= 12 &&
        RegExp(r'\d').hasMatch(password);
  }

  bool _isEmailValid(String email) {
    return RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$").hasMatch(email);
  }

  void _showDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;


    final horizontalPadding = screenWidth > 600 ? screenWidth * 0.3 : 50.0;

    return Scaffold(
      backgroundColor: Color(0xFF070707),
      body: Container(
        alignment: Alignment.center,
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Tik tok',
                style: TextStyle(
                  fontSize: 35,
                  color: Colors.red,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text(
                'Регистрация',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 25),
              Container(
                margin: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: TextInputField(
                  controller: _usernameController,
                  labelText: 'Имя пользователя',
                  icon: Icons.person,
                ),
              ),
              const SizedBox(height: 15),
              Container(
                margin: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: TextInputField(
                  controller: _emailController,
                  labelText: 'Email',
                  icon: Icons.email,
                ),
              ),
              const SizedBox(height: 15),
              Container(
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
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: InkWell(
                  onTap: () async {
                    final username = _usernameController.text.trim();
                    final email = _emailController.text.trim();
                    final password = _passwordController.text;

                    if (username.isEmpty || email.isEmpty || password.isEmpty) {
                      _showDialog(context, 'Ошибка', 'Все поля должны быть заполнены.');
                      return;
                    }

                    if (!_isEmailValid(email)) {
                      _showDialog(context, 'Ошибка', 'Введите корректный email.');
                      return;
                    }

                    if (!_isPasswordValid(password)) {
                      _showDialog(
                        context,
                        'Ошибка',
                        'Пароль должен быть от 6 до 12 символов и содержать хотя бы одну цифру.',
                      );
                      return;
                    }

                    try {

                      final emailCheck = await Supabase.instance.client
                          .from('user')
                          .select()
                          .eq('email', email)
                          .maybeSingle();

                      if (emailCheck != null) {
                        _showDialog(context, 'Ошибка', 'Пользователь с таким email уже существует.');
                        return;
                      }


                      final usernameCheck = await Supabase.instance.client
                          .from('user')
                          .select()
                          .eq('user_name', username)
                          .maybeSingle();

                      if (usernameCheck != null) {
                        _showDialog(context, 'Ошибка', 'Пользователь с таким именем уже существует.');
                        return;
                      }


                      final hashedPassword = BCrypt.hashpw(password, BCrypt.gensalt());


                      final response = await Supabase.instance.client.auth.signUp(
                        email: email,
                        password: password,
                      );

                      if (response.user != null) {
                        final userId = response.user!.id;

                        const defaultImageUrl =
                            'https://ehdliqszkyprsiurkjwf.supabase.co/storage/v1/object/public/photos/profile.png';

                        await Supabase.instance.client.from('user').insert({
                          'id': userId,
                          'user_name': username,
                          'email': email,
                          'profile_image_url': defaultImageUrl,
                          'password': hashedPassword,
                          'created_at': DateTime.now().toUtc().toIso8601String(),
                          'updated_at': DateTime.now().toUtc().toIso8601String(),
                        });

                        _showDialog(
                          context,
                          'Успех',
                          'Подтверждение Email выслано на указанную почту',
                        );

                        Future.delayed(const Duration(seconds: 5), () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (context) => LoginScreen()),
                          );
                        });
                      } else {
                        _showDialog(context, 'Ошибка', 'Не удалось создать пользователя.');
                      }
                    } catch (e) {
                      _showDialog(context, 'Ошибка регистрации', '$e');
                    }
                  },
                  child: const Center(
                    child: Text(
                      'Зарегистрироваться',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Уже есть аккаунт? ', style: TextStyle(fontSize: 20, color:Colors.white, )),
                  InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => LoginScreen()),
                    ),
                    child: const Text(
                      'Войти',
                      style: TextStyle(fontSize: 20, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
