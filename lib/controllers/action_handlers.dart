import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rxdart/rxdart.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:folder_picker/folder_picker.dart';
import 'package:workmanager/workmanager.dart';

import 'package:ural/controllers/image_handler.dart';
import 'package:ural/pages/textview.dart';
import 'package:ural/utils/parsers.dart';
import 'package:ural/urls.dart';
import 'package:ural/blocs/auth_bloc.dart';
import 'package:ural/models/screen_model.dart';

enum SearchStates { searching, finished, empty }

/// Handles Settings button events
void handleSettings() async {
  // print(await uploadImagesToBackground());
}

/// Gets called when manual-upload button called
void handleManualUpload() {}

///Handle textView events
void handleTextView(BuildContext context, TextRecognizer textRecognizer) async {
  File image = await ImagePicker.pickImage(source: ImageSource.gallery);
  final blocks = await recognizeImage(image, textRecognizer, getBlocks: true);
  Navigator.push(
      context,
      MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) => TextView(
                textBlocks: blocks,
              )));
}

/// Handles textField or searchField queries
Future<List<ScreenModel>> handleTextField({
  String query,
  PageController pageController,
  BehaviorSubject<SearchStates> searchSubject,
}) async {
  List<ScreenModel> searchResults;
  pageController.nextPage(
      duration: Duration(milliseconds: 350),
      curve: Curves.fastLinearToSlowEaseIn);

  searchSubject.add(SearchStates.searching);

  String url = ApiUrls.root + ApiUrls.search + "?query=$query";
  try {
    final response = await http.get(url,
        headers: ApiUrls.authenticatedHeader(Auth().user.token));
    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);

      searchResults = parseModelFromJson(jsonData);
      if (searchResults.length > 0) {
        searchSubject.add(SearchStates.finished);
      } else {
        searchSubject.add(SearchStates.empty);
      }
    }
  } catch (e) {
    print(e);
  }
  return searchResults;
}

void handleDirectory(BuildContext context) async {
  final pref = await SharedPreferences.getInstance();
  final defaultDir = pref.getString("ural_default_folder");

  showDialog(
      context: context,
      child: AlertDialog(
        title: Text("Default Directory"),
        content: Text(defaultDir == null ? "NOT SET" : defaultDir),
        actions: <Widget>[
          FlatButton(
              onPressed: () => Navigator.pop(context), child: Text("Close")),
          FlatButton(
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (context) => FolderPickerPage(
                            action: (context, directory) async {
                              setDefaultFolder(directory.path);
                              Navigator.pop(context);
                            },
                            rootDirectory: Directory("/storage/emulated/0/"))));
              },
              child: Text("Change Folder")),
        ],
      ));
}

void setDefaultFolder(String path) async {
  final pref = await SharedPreferences.getInstance();
  pref.setString("ural_default_folder", path);
}

void startBackGroundJob() async {
  await Workmanager.registerPeriodicTask("uralfetchscreens", "ural_background",
      initialDelay: Duration(seconds: 5));
}
