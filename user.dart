import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class User {
  final int ID;                                                //ID користувача;
  final String email;                                          //Електронна пошта користувача;
  final String nameFirst;                                      //Ім'я користувача;
  final String nameLast;                                       //Прізвище користувача;
  final String urlImage;                                       //Адреса аватара користувача;
  bool isDownloaded;                                           //Чи скачався аватар користувача;


  User({
    required this.ID,
    required this.email,
    required this.nameFirst,
    required this.nameLast,
    required this.urlImage,
    this.isDownloaded = false,
  });

  Map<String, dynamic> toJSON() => {                           //Імпорт даних з API в JSON;
    'ID': ID,
    'email': email,
    'nameFirst': nameFirst,
    'nameLast': nameLast,
    'urlImage': urlImage,
    'isDownloaded': isDownloaded,
  };

  factory User.fromJson(Map<String, dynamic> json) {           //Створення об'єкта "Користувач" з данних JSON;
    return User(
        ID: json['ID'],
        email: json['email'],
        nameFirst: json['nameFirst'],
        nameLast: json['nameLast'],
        urlImage: json['urlImage'],
      isDownloaded: json['isDownloaded'] ?? false,
    );
  }

  static Map<String, dynamic> toMap(User user) => {           //Перетворення User в Map<String, dynamic>;
    'ID': user.ID,
    'email': user.email,
    'nameFirst': user.nameFirst,
    'nameLast': user.nameLast,
    'urlImage': user.urlImage,
    'isDownloaded': user.isDownloaded,
  };

  static String encode(List<User> users) => json.encode(     //Шифрування списку користувачів;
    users
        .map<Map<String, dynamic>>((user) => User.toMap(user))
        .toList(),
  );

  static List<User> decode(String users) =>                  //Декодування списку користувачів
      (json.decode(users) as List<dynamic>)
          .map<User>((item) => User.fromJson(item))
          .toList();

  Future<void> downloadAndSaveImage() async {                //Завантаження та збереження аватарків;
    final directory = await getApplicationDocumentsDirectory();       //Каталог документів програми;
    final filePath = '${directory.path}/${ID}-image.jpg';             //Створення щляху для аватарки;

    final response = await http.get(Uri.parse(urlImage));             //Завантаження аватарки;
    final file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);                      //Збереження аватарки в файлу;
    isDownloaded = true;                                              //Підтвердження завантаження;
  }

  Future<String> getLocalImagePath() async {                          //Повернення шляху до аватарки;
    final appDir = await getApplicationDocumentsDirectory();          //Каталог документів програми;
    final imageName = '$ID-image.jpg';                                //Назва аватарки;
    return '${appDir.path}/images/$imageName';
  }
}
