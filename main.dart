import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:get/get.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const GetMaterialApp(home: UserList()));

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const GetMaterialApp(
      home: UserList(),
    );
  }
}

class UserList extends StatefulWidget {
  const UserList({super.key});

  @override
  _UserListState createState() => _UserListState();
}

class Controller extends GetxController {
  final users = <User>[].obs;                                                //Список користувачів;
  var barname = RxString("");                                                //Назва шапки;
  var isCheckingConnection = true.obs;                                       //Перевірка з'єднання триває?
  var isConnected = false.obs;                                               //Чи є з'єднання?

  @override
  void onInit() {
    super.onInit();
    checkConnectionAndFetchUsers();
  }

  void updateUsers(List<User> newUsers) {                                    //Обновлення списку користувачів;
    users.assignAll(newUsers);
    update();
  }

  Future<void> _loadUsers() async {                                          //Завантаження списку збереженних користувачів;
    SharedPreferences prefs = await SharedPreferences.getInstance();         //Екземпляр shared_preferences для зберігання даних;
    final String usersString = prefs.getString('users_key') ?? '[]';         //Зчитування даних з ключа(якщо даних немає - порожній рядок);

    List<User> loadedUsers = User.decode(usersString);                       //Декодування списку користувачів з shared_preferences;

    List<User> updatedUsers = [];                                            //Тимчасовий список користувачів з shared_preferences;

    for (var user in loadedUsers) {
      String localImagePath = await user.getLocalImagePath();                //Шлях до аватарки конкретного користувача;
      user.isDownloaded = await File(localImagePath).exists();               //Перевірка наявності аватарки;
      updatedUsers.add(user);                                                //Добавлення користувача в тимчасовий список;
    }

    updateUsers(updatedUsers);                                               //Переміщення користувачів з тимчасового списку до списку користувачів;
    barname.value = "Список користувачів(оффлайн)";                          //Зміна тексту шапки;
    update();                                                                //Оновлення змінних;
  }

  Future<void> _saveUsers() async {                                           //Збереження користувачів в список;
    SharedPreferences prefs = await SharedPreferences.getInstance();          //Екземпляр shared_preferences для зберігання даних;
    final String savedData = User.encode(users);                              //Шифрування списку користувачів в shared_preferences;
    await prefs.setString('users_key', savedData);                            //Запис даних в shared_preferences;
  }

  Future<void> checkConnectionAndFetchUsers() async {                         //Перевірка з'єднання та отримання списку користувачів(у випадку наявності з'єднання);
    isCheckingConnection.value = true;
    update();                                                                 //Оновлення змінних;

    isConnected.value = false;
    try {
      isConnected.value =
          await checkConnection().timeout(const Duration(seconds: 10));       //Очікування з'єднання протягом 10 секунд;
    } on TimeoutException {                                                   //Якщо 10 секунд пройшли, але з'єднання немає;
      // Handle the timeout here
      isConnected.value = false;
    }

    if (isConnected.value == true) {                                          //Якщо підключено до інтернету;
      getUsers();
    } else {                                                                  //Якщо ні;
      _loadUsers();
    }

    isCheckingConnection.value = false;
    update();                                                                 //Оновлення даних;
  }

  Future<bool> checkConnection() async {                                      //Перевірка з'єднання;
    try {
      final res = await InternetAddress.lookup('google.com');                 //Очікування з'єднання;
      if (res.isNotEmpty && res[0].rawAddress.isNotEmpty) {                   //Якщо з'єднання наявне;
        return true;
      } else {                                                                //Якщо ні;
        return false;
      }
    } on SocketException catch (_) {                                          //Якщо проблеми з мережою;
      return false;
    }
  }

  Future<void> getUsers() async {                                             //Отримання користувачів з API;
    var response = await http.get(Uri.https('reqres.in', 'api/users', {       //Запит з API-пункту;
      'page': '2',
    }));
    var jsonData = jsonDecode(response.body);                                //Отримання даних з запиту;

    if(users.isNotEmpty) {                                                   //Якщо в спискові є дані(видалення ідентичних даних);

      users.clear();
    }

    List<User> newUsers = [];                                                //Тимчасовий список користувачів;

    for (var eachUser in jsonData['data']) {
      final user = User(                                                     //Стоврення даних про користувача з даними з JSON;
          ID: eachUser['id'],
          email: eachUser['email'],
          nameFirst: eachUser['first_name'],
          nameLast: eachUser['last_name'],
          urlImage: eachUser['avatar']);

      newUsers.add(user);                                                    //Добавлення користувача в тимчасовий список;

      if (!user.isDownloaded) {                                              //Якщо аватарка не завантажена;
        await user.downloadAndSaveImage();                                   //Завантаження аватарки;
      }
    }

    updateUsers(newUsers);                                                   //Переміщення користувачів з тимчасового списку до списку користувачів;
    barname.value = "Список користувачів";                                   //Зміна тексту шапки;
    update();                                                                //Оновлення змінних;

    _saveUsers();                                                            //Збереження даних;
  }
}

class _UserListState extends State<UserList> {
  final Controller userController = Get.put(Controller());

  @override
  void initState() {
    super.initState();
    userController.checkConnectionAndFetchUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Obx(() => Text(userController.barname.value))),
        body: Obx(() {
          if (userController.isCheckingConnection.value == true) {
            return const CheckingConnectionScreen();
          } else {
            return ListView.builder(
              itemCount: userController.users.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                    onTap: () {
                      if(userController.isConnected.isTrue) {
                        Get.to(() =>
                            DetailInfo(userController.users[index].ID));
                      }
                    },
                    child: Card(
                      color: Colors.blue,
                      child: Row(
                        children: [
                          CachedNetworkImage(
                            imageUrl: userController.users[index].urlImage,
                            fit: BoxFit.cover,
                            width: 100,
                            height: 100,
                          ),
                          Expanded(
                            child: Align(
                              alignment: Alignment.center,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                      "${userController.users[index].nameFirst} ${userController.users[index].nameLast}"),
                                  Text(userController.users[index].email),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ));
              },
            );
          }
        }));
  }
}

class CheckingConnectionScreen extends StatelessWidget {
  const CheckingConnectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              LoadingAnimationWidget.threeArchedCircle(
                  color: Colors.black, size: 60),
              const SizedBox(height: 4),
              const Text(
                'Очікування підключення',
                style: TextStyle(fontSize: 25, color: Colors.black),
              ),
              const SizedBox(height: 4),
              const Text(
                'Якщо за 10 секунд не буде з\'єднання,'
                    ' будуть відображенні збереженні дані',
                style: TextStyle(fontSize: 20, color: Colors.black),
                textAlign: TextAlign.center,
              ),
            ]),
      ),
    );
  }
}

class DetailInfo extends StatelessWidget {
  String userID = "";                                                        //ID користувача;

  DetailInfo(int userID, {super.key}) {
    this.userID = userID.toString();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: fetchUserInfo(userID),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: Colors.white,
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  LoadingAnimationWidget.threeArchedCircle(
                      color: Colors.black, size: 60),
                  const Text(
                    'Очікування інформації',
                    style: TextStyle(fontSize: 25, color: Colors.black),
                  ),
                ]),
          );
        } else if (snapshot.hasError) {
          return const Text('Error loading user details');
        } else {
          var user = snapshot
              .data?['data']; // Accessing the 'data' section of the response

          return Scaffold(
            appBar: AppBar(
              title: Text("${user['first_name']} ${user['last_name']}"),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.network(
                    user['avatar'], // Using the 'avatar' URL from the response
                    fit: BoxFit.cover,
                    width: 300,
                    height: 300,
                  ),
                  Text(
                    "ID: ${user['id']}",
                    style: const TextStyle(fontSize: 25),
                  ),
                  Text(
                    "Ім'я: ${user['first_name']}",
                    style: const TextStyle(fontSize: 25),
                  ),
                  Text(
                    "Прізвище: ${user['last_name']}",
                    style: const TextStyle(fontSize: 25),
                  ),
                  const Text(
                    "Електронна пошта:",
                    style: TextStyle(fontSize: 25),
                  ),
                  Text(
                    "${user['email']}",
                    style: const TextStyle(fontSize: 25),
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }

  Future<Map<String, dynamic>> fetchUserInfo(String userID) async {          //Збирання даних про користувача за ID;
    var response = await http.get(Uri.https("reqres.in", "api/users/$userID"));   //Запит в API-пункту;
    var userDetail = jsonDecode(response.body);                              //Отримання даних з запиту;
    return userDetail;
  }
}
