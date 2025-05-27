import 'dart:convert';

import 'package:arcgis_maps/arcgis_maps.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'token_provider.dart';

Future<void> main() async {
  await dotenv.load(fileName: '.env');

  ArcGISEnvironment.authenticationManager.arcGISCredentialStore =
      await ArcGISCredentialStore.initPersistentStore();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  static final _portalUri = Uri.parse('https://www.arcgis.com');
  static final _oAuthUserConfiguration = OAuthUserConfiguration(
    portalUri: _portalUri,
    clientId: dotenv.get('OAUTH_CLIENT_ID'),
    redirectUri: Uri.parse(dotenv.get('OAUTH_REDIRECT_URI')),
  );
  final _tokenProvider = TokenProvider(oAuthUserConfiguration: _oAuthUserConfiguration);

  late final FeatureTable _pointFeatureTable;
  late final FeatureLayer _pointFeatureLayer;
  late final ServiceFeatureTable _buffersFeatureTable;

  final _mapViewController = ArcGISMapView.createController();
  final _buffersLayer = GraphicsOverlay();

  @override
  void initState() {
    super.initState();

    final featureServerUri = Uri.parse(dotenv.get('FEATURE_SERVER_URI'));

    _pointFeatureTable = ServiceFeatureTable.withUri(Uri.parse(
        "$featureServerUri/0/"
    ));
    _pointFeatureLayer = FeatureLayer.withFeatureTable(_pointFeatureTable);

    _buffersFeatureTable = ServiceFeatureTable.withUri(Uri.parse(
        "$featureServerUri/1/"
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          ElevatedButton(
              onPressed: () {
                _buffersLayer.graphics.clear();
              },
              child: Text("Clear buffers")
          ),
          Expanded(
            child: ArcGISMapView(
              controllerProvider: () => _mapViewController,
              onMapViewReady: _onMapViewReady,
              onTap: _onTap,
            ),
          ),
        ],
      ),
    );
  }

  void _onMapViewReady() async {
    final map = ArcGISMap.withItem(PortalItem.withPortalAndItemId(
        portal: Portal.arcGISOnline(connection: PortalConnection.authenticated),
        itemId: "22fb75c0fa5a4c88b8ca4c4b8ae5c90b"));

    map.operationalLayers.add(_pointFeatureLayer);
    await _pointFeatureLayer.load();

    map.tables.add(_buffersFeatureTable);

    _mapViewController.graphicsOverlays.add(_buffersLayer);

    _mapViewController.arcGISMap = map;
  }

  void _onTap(localPosition) async {
    final queryParameters = QueryParameters();

    queryParameters.whereClause = "RELID = '{1d0102e2-c130-4e5b-8631-be8bd8374990}'"; // 3 rings.
    // queryParameters.whereClause = "OBJECTID = 427"; // works well: returns single feature
    // queryParameters.whereClause = "RELID = '452df3d4-ec43-4118-b898-271eb8bb6cb3'"; // 1 ring.
    queryParameters.orderByFields.add(
        OrderBy(fieldName: "RING", sortOrder: SortOrder.descending)
    );

    final queryResult = await _buffersFeatureTable.queryFeaturesWithFieldOptions(
        parameters: queryParameters, queryFeatureFields: QueryFeatureFields.loadAll);

    final features = queryResult.features().toList();
    if (features.isEmpty) {
      print("no features queried");
    } else {
      print("features num: ${features.length}");
    }

    _orderRings(features, "RING");

    _buffersLayer.graphics.clear();

    final graphics = features.map((feature) {
      final symbolString = feature.attributes["SYMBOL"] as String;
      final json = jsonDecode(symbolString);
      final symbol = ArcGISSymbol.fromJson(json);

      return Graphic(
        geometry: feature.geometry,
        attributes: feature.attributes,
        symbol: symbol,
      );
    });

    _buffersLayer.graphics.addAll(graphics);

    final lastGeometry = graphics.first.geometry!;

    _mapViewController.setViewpointGeometry(lastGeometry, paddingInDiPs: 50);
  }

  // manual rings ordering according to value of [ringFieldName]
  void _orderRings(List<Feature> rings, String? ringFieldName) {
    rings.sort((f1, f2) {
      int? ring1 = f1.attributes[ringFieldName];
      int? ring2 = f2.attributes[ringFieldName];

      return (ring1 != null && ring2 != null) ? (ring1.compareTo(ring2)) : 0;
    });
  }
}