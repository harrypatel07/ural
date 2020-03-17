import 'dart:convert';
import 'package:after_layout/after_layout.dart';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/material.dart';
// import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ural/blocs/screen_bloc.dart';
// import 'package:ural/database.dart';
import 'package:workmanager/workmanager.dart';
import 'dart:io';
// import 'package:http/http.dart' as http;
import 'dart:async';

// import 'auth_dialog.dart';
// import 'package:ural/models/screen_model.dart';
import 'package:ural/pages/home_body.dart';
// import 'package:ural/urls.dart';
import 'package:ural/utils/async.dart';
import 'controllers/permission_handler.dart';
// import 'blocs/auth_bloc.dart';
import 'controllers/action_handlers.dart';
// import 'utils/parsers.dart';
import 'controllers/image_handler.dart';

Future<bool> uploadImagesToBackground() async {
  final pref = await SharedPreferences.getInstance();
  if (pref.containsKey("ural_default_folder")) {
    final dir = Directory(pref.getString("ural_default_folder"));
    final token = pref.getString("uralToken");
    final textRecognizer = FirebaseVision.instance.textRecognizer();
    var config;
    if (pref.containsKey("ural_synced_config")) {
      config = json.decode(pref.getString("ural_synced_config"));
    } else {
      config = {};
    }
    int count = 0;
    List<FileSystemEntity> fileEntities = dir.listSync(recursive: true);
    for (FileSystemEntity entity in fileEntities) {
      if (entity is File) {
        if (config.containsKey(entity.path.hashCode.toString())) continue;
        if (count > 20) break;
        final result =
            await syncImageToServer(File(entity.path), textRecognizer, token);
        if (result.state == ResponseStatus.success) {
          config[entity.path.hashCode.toString()] = "";
          count++;
        }
      }
    }
    return true;
  }
  return false;
}

void callbackDispatcher() {
  print("CallBackDispacther RUNNING");
  Workmanager.executeTask((task, input) async {
    return await uploadImagesToBackground();
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Workmanager.initialize(callbackDispatcher, isInDebugMode: false);
  runApp(App());
}

class App extends StatelessWidget {
  const App({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primaryColor: Color(0xFF424242),
        primaryColorLight: Color(0xFF6d6d6d),
        primaryColorDark: Color(0xFF1b1b1b),
        accentColor: Color(0xFFe91e63),
        scaffoldBackgroundColor: Color(0xFF6d6d6d),
        canvasColor: Color(0xFF1b1b1b),
        backgroundColor: Color(0xFF1b1b1b),
      ),
      routes: {"/": (context) => Home()},
    );
  }
}

class Home extends StatefulWidget {
  Home({Key key}) : super(key: key);

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> with AfterLayoutMixin {
  ScreenBloc _bloc = ScreenBloc();

  final PageController _pageController = PageController();
  final _scaffold = GlobalKey<ScaffoldState>();
  final recognizer = FirebaseVision.instance.textRecognizer();

  @override
  void initState() {
    super.initState();
    startup();
  }

  void startup() async {
    //gotta wait for database to get initialized
    await _bloc.initializeDatabase();
    //then lazily load all the screens
    _bloc.listAllScreens();
  }

  @override
  void dispose() {
    _bloc.dispose();
    super.dispose();
  }

  // void getImagesList() async {
  //   String url = ApiUrls.root + ApiUrls.images;
  //   try {
  //     final response = await http.get(url,
  //         headers: ApiUrls.authenticatedHeader(Auth().user.token));
  //     if (response.statusCode == 200) {
  //       final jsonData = json.decode(response.body);

  //       setState(() {
  //         screenshots = parseModelFromJson(jsonData);
  //       });
  //     }
  //   } catch (e) {
  //     print(e);
  //   }
  // }

  @override
  void afterFirstLayout(BuildContext context) async {
    await getPermissionStatus();
    // slDB.initDB();
    // final authState = await Auth().authenticate();
    // if (authState.state == ResponseStatus.failed)
    //   await showDialog(
    //     context: context,
    //     child: AuthenticationDialog(),
    //     barrierDismissible: false,
    //   );

    // getImagesList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffold,
      body: NestedScrollView(
        headerSliverBuilder: (context, isBoxScroll) => [
          SliverAppBar(
            pinned: true,
            floating: true,
            forceElevated: isBoxScroll,
            title: Container(height: 40, child: Text("Ural")),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                margin: EdgeInsets.only(top: 60),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      padding: EdgeInsets.all(8),
                      height: 110,
                      width: MediaQuery.of(context).size.width,
                      child: Center(
                        child: Card(
                          child: ListTile(
                            title: TextField(
                              onSubmitted: (val) async {
                                _bloc.handleTextField(
                                    query: val,
                                    pageController: _pageController);
                              },
                              decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText:
                                      "Type what you're looking for here"),
                            ),
                            trailing: IconButton(
                                icon: Icon(Icons.search), onPressed: null),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: MediaQuery.of(context).size.width * 0.8,
                      child: Wrap(
                        alignment: WrapAlignment.spaceEvenly,
                        children: <Widget>[
                          FloatingActionButton(
                            elevation: 0,
                            heroTag: null,
                            onPressed: () {
                              _bloc.handleManualUpload(_scaffold);
                            },
                            child: Icon(Icons.file_upload),
                          ),
                          FloatingActionButton(
                            elevation: 0,
                            heroTag: null,
                            onPressed: () async {
                              handleTextView(context, recognizer);
                            },
                            child: Icon(Icons.text_fields),
                          ),
                          FloatingActionButton(
                            elevation: 0,
                            heroTag: null,
                            onPressed: () {
                              handleBackgroundSync(_scaffold);
                            },
                            child: Icon(Icons.sync),
                          ),
                          FloatingActionButton(
                            heroTag: null,
                            elevation: 0,
                            child: Icon(Icons.settings),
                            onPressed: () {
                              _bloc.handleSettings(context);
                            },
                          )
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
            expandedHeight: 220,
          ),
        ],
        body: PageView(
          controller: _pageController,
          physics: NeverScrollableScrollPhysics(),
          children: <Widget>[
            StreamBuilder<StreamEvents>(
              stream: _bloc.streamOfRecentScreens,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  if (snapshot.data == StreamEvents.loading) {
                    return Material(
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  } else {
                    return HomeBody(
                      title: "Recent Screenshots",
                      screenshots: _bloc.recentScreenshots,
                    );
                  }
                }
                return Container();
              },
            ),
            StreamBuilder<SearchStates>(
              stream: _bloc.streamofSearchResults,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  if (snapshot.data == SearchStates.finished) {
                    return HomeBody(
                      title: "Search results",
                      screenshots: _bloc.searchResults,
                    );
                  }
                  if (snapshot.data == SearchStates.empty) {
                    return Material(
                      child: Center(
                        child: Text(
                          "Couldn't find anything. Please trying typing something else",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    );
                  }
                }
                return Material(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: StreamBuilder<SearchStates>(
          stream: _bloc.streamofSearchResults,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              if (snapshot.data != SearchStates.searching)
                return FloatingActionButton(
                  heroTag: null,
                  onPressed: () {
                    _pageController.previousPage(
                        duration: Duration(milliseconds: 400),
                        curve: Curves.easeIn);
                  },
                  child: Icon(Icons.grid_on),
                );
              else
                return Container();
            }
            return Container();
          }),
    );
  }
}
