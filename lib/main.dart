import 'package:arcgis_maps/arcgis_maps.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'token_provider.dart';

Future<void> main() async {
  await dotenv.load(fileName: '.env');

  ArcGISEnvironment.apiKey = dotenv.get('OAUTH_TOKEN');
  // ArcGISEnvironment.authenticationManager.arcGISCredentialStore =
  //     await ArcGISCredentialStore.initPersistentStore();

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
  // late final FeatureLayer _buffersFeatureLayer;

  FeatureCollectionLayer? _fcLayer;

  final _mapViewController = ArcGISMapView.createController();
  static final _emptyDefExpression = "1!=1";

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
    // _buffersFeatureLayer =
    //     FeatureLayer.withFeatureTable(_buffersFeatureTable)
    //     ..definitionExpression = _emptyDefExpression; // don't load and show anything


    // var _buffersFeatureLayer =
    //     FeatureLayer.withFeatureTable(_buffersFeatureTable)


    // final displayFilter = DisplayFilter.withWhereClause(name: "display filter name", whereClause: "1=1");
    // // ORDER BY RING
    // _buffersFeatureLayer.displayFilterDefinition =
    //     ManualDisplayFilterDefinition.withFilters(activeFilter: displayFilter,
    //         availableFilters: [displayFilter]);
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
              onPressed: () async {
                // final defExpression = _buffersFeatureLayer.definitionExpression;
                // print("defExpression for features querying: $defExpression");
                //
                // final parameters = QueryParameters();
                // parameters.whereClause = defExpression;
                //
                // final queryResult = await _buffersFeatureLayer.selectFeaturesWithQuery(
                //     parameters: parameters, mode: SelectionMode.new_);
                //
                // final features = queryResult.features().toList();
                // print("Queried Features count: ${features.length}");
                // _buffersFeatureLayer.clearSelection(); // no highlight needed
              }, child: Text("Grab features")
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

    // map.operationalLayers.add(_buffersFeatureLayer);

    map.operationalLayers.add(_pointFeatureLayer);
    map.initialViewpoint = Viewpoint.fromCenter(
      ArcGISPoint(
        x: -117.048625,
        y: 32.537078,
        spatialReference: SpatialReference.wgs84,
      ),
      scale: 110000,
    );
    await map.load();

    _mapViewController.arcGISMap = map;
  }

  void _onTap(localPosition) async {
    final globalId = await _getGlobalId(localPosition);
    print("GLOBALID: $globalId");
    final defExpression = "RELID = '${globalId?.toString()}'"; // {1d0102e2-c130-4e5b-8631-be8bd8374990}
    print("Definition expression: $defExpression");

    // ORDER BY RING
    // _buffersFeatureLayer.definitionExpression = defExpression;

    // print("Definition expression set: ${_buffersFeatureLayer.definitionExpression}");

    ///--- several requests: 1 per RING

    // final fcTables = await Future.wait([3, 2, 1].map((ringId) async {
    //   final defExpression = "RELID = '${globalId?.toString()}' AND RING = $ringId";
    //
    //   final parameters = QueryParameters();
    //   parameters.whereClause = defExpression;
    //
    //   // _buffersFeatureTable.queryFeaturesWithFieldOptions(parameters: parameters, queryFeatureFields: queryFeatureFields)
    //
    //   // final queryResult = await _buffersFeatureLayer.selectFeaturesWithQuery(
    //   //     parameters: parameters, mode: SelectionMode.new_);
    //
    //   // final queryResult = await _buffersFeatureTable.queryFeatures(parameters);
    //   final queryResult = await _buffersFeatureTable.queryFeaturesWithFieldOptions(
    //       parameters: parameters, queryFeatureFields: QueryFeatureFields.loadAll);
    //
    //   if (queryResult.features().isNotEmpty) {
    //     final renderer = SimpleRenderer(
    //       symbol: ArcGISSymbol.fromJsonString(queryResult.features().first.attributes["SYMBOL"]),
    //     );
    //
    //     return FeatureCollectionTable.withFeatureSet(queryResult)
    //     ..renderer = renderer;
    //   }
    // }));

    // FeatureCollection fc = FeatureCollection.withTables(fcTables.nonNulls.toList());


    /// --- single request for all RINGs

    final parameters = QueryParameters();
    parameters.whereClause = defExpression;
    parameters.orderByFields.add(
      OrderBy(fieldName: "RING", sortOrder: SortOrder.ascending)
    );

    final queryResult = await _buffersFeatureTable.queryFeaturesWithFieldOptions(
        parameters: parameters, queryFeatureFields: QueryFeatureFields.loadAll);

    if (queryResult.features().isEmpty) {
      print("Result query has no features");
      return;
    }

    final features = queryResult.features().toList();
    // _orderRings(features, "RING");

    final fcTables = features.reversed.map((feature) { // reversed to put on map in correct order
      print("New FeatureTable, RING: ${feature.attributes['ring']}");
      // works well
      final fcTable = FeatureCollectionTable(
        fields: queryResult.fields,
        geometryType: queryResult.geometryType,
        spatialReference: queryResult.spatialReference,
      )
      ..addFeature(feature);

      // fails with exception: 'Unsupported element type'
      // final fcTable = FeatureCollectionTable.withGeoElements(
      //     geoElements: [feature],
      //     fields: queryResult.fields);

      // fails with exception: 'Unsupported element type'
      // final graphic = Graphic(
      //   geometry: feature.geometry,
      //   attributes: feature.attributes,
      //   symbol: ArcGISSymbol.fromJsonString(feature.attributes["SYMBOL"]),
      // );
      // final fcTable = FeatureCollectionTable.withGeoElements(
      //     geoElements: [graphic],
      //     fields: queryResult.fields);

      fcTable.renderer = SimpleRenderer(
        symbol: ArcGISSymbol.fromJsonString(feature.attributes["SYMBOL"]),
      );

      return fcTable;
    });


    /// --- adding to map

    FeatureCollection fc = FeatureCollection.withTables(fcTables.toList());

    if (_fcLayer != null) {
      _mapViewController.arcGISMap?.operationalLayers.remove(_fcLayer);
    }

    _fcLayer = FeatureCollectionLayer.withFeatureCollection(fc);

    _mapViewController.arcGISMap?.operationalLayers.insert(0, _fcLayer!);
  }

  Future<Guid?> _getGlobalId(Offset localPosition) async {
    final identifyLayerResults = await _mapViewController.identifyLayers(
      screenPoint: localPosition,
      tolerance: 12,
    );

    // handle only 1 result from 1 layer simultaneously
    final result = identifyLayerResults.firstOrNull;
    final element = result?.geoElements.firstOrNull;

    return element?.attributes["GLOBALID"];
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