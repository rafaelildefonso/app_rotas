// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapa_teste/getUserLocation.dart';
import 'package:mapa_teste/pickedplace_page.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OSMPlacePicker extends StatefulWidget {
  @override
  _OSMPlacePickerState createState() => _OSMPlacePickerState();
}

class _OSMPlacePickerState extends State<OSMPlacePicker> {
  late MapController _mapController;
  LatLng? selectedPosition;
  LatLng? userPosition;
  List<LatLng> _routePoints = []; // Para armazenar os pontos da rota
  bool _isFetchingRoute = false; // Para mostrar um indicador de carregamento

  // IMPORTANTE: Substitua pela sua chave de API do OpenRouteService
  // Em produção, NUNCA coloque a chave diretamente no código.
  final String _orsApiKey = dotenv.env['ORS_API_KEY'] ?? 'CHAVE_NAO_ENCONTRADA';

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    print("PlacePicker: initState - Inicializando...");

    // --- PARA TESTE: Use uma localização fixa para ver se o mapa carrega ---
    // Se o mapa carregar com a linha abaixo, o problema está em getCurrentLocation()
    // _initializeWithFixedLocation();
    // return;
    // --------------------------------------------------------------------

    getCurrentLocation().then((position) {
      print("PlacePicker: Localização obtida - Lat: ${position.latitude}, Lng: ${position.longitude}");
      if (mounted) { // Garante que o widget ainda está na árvore
        setState(() {
          userPosition = LatLng(position.latitude, position.longitude);
          selectedPosition = LatLng(position.latitude, position.longitude);
          print("PlacePicker: userPosition e selectedPosition atualizados.");
        });
      }
    }).catchError((error) {
      print("PlacePicker: Erro ao obter localização: $error");
      if (mounted) {
        // Considere mostrar uma mensagem de erro para o usuário aqui
        // Por exemplo, usando um SnackBar ou atualizando o estado para mostrar um widget de erro.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao obter sua localização: $error')),
        );
        // Poderia definir uma localização padrão ou deixar o CircularProgressIndicator
      }
    });
  }

  Future<void> _fetchAndDisplayRoute() async {
    if (userPosition == null || selectedPosition == null) {
      print("Posição do usuário ou selecionada não definida para buscar rota.");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Defina um ponto de partida e chegada no mapa.')),
      );
      return;
    }

    if (_orsApiKey == 'CHAVE_NAO_ENCONTRADA' || _orsApiKey.isEmpty) {
      print("Chave da API do OpenRouteService não configurada.");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chave da API do OpenRouteService não configurada.')),
      );
      return;
    }

    setState(() {
      _isFetchingRoute = true;
      _routePoints = []; // Limpa a rota anterior
    });

    // Perfil de rota (ex: driving-car, foot-walking, cycling-regular)
    String profile = 'driving-car';
    String url =
        'https://api.openrouteservice.org/v2/directions/$profile/geojson';

    // Coordenadas no formato [longitude,latitude] exigido pela API
    List<List<double>> coordinates = [
      [userPosition!.longitude, userPosition!.latitude],
      [selectedPosition!.longitude, selectedPosition!.latitude]
    ];

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': _orsApiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'coordinates': coordinates}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> coords = data['features'][0]['geometry']['coordinates'];
        setState(() {
          _routePoints = coords.map((coord) => LatLng(coord[1], coord[0])).toList();
        });
      } else {
        print('Erro na API OpenRouteService: ${response.statusCode} - ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao buscar rota: ${response.reasonPhrase}')),
        );
      }
    } catch (e) {
      print('Exceção ao buscar rota: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro de conexão ao buscar rota.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingRoute = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Escolher Local (OSM)')),
      body:
          userPosition == null && !_isFetchingRoute
              ? Center(child: CircularProgressIndicator(key: Key("initialLoader")))
              : _isFetchingRoute
              ? Center(child: CircularProgressIndicator(key: Key("routeLoader")))
              : Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: userPosition!,
                      initialZoom: 15.0,
                      onPositionChanged: (position, hasGesture) {
                        if (hasGesture) {
                          setState(() {
                            selectedPosition = position.center;
                          });
                        }
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            // OSM recomenda não usar subdomínios.
                            // Veja: https://github.com/openstreetmap/operations/issues/737
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        // É uma boa prática adicionar o userAgentPackageName.
                        // Substitua 'com.example.mapa_teste' pelo nome do pacote do seu app.
                        userAgentPackageName: 'com.example.mapa_teste',
                        errorTileCallback: (tile, error, stackTrace) {
                          print('Erro ao carregar tile: ${tile.coordinates}, Erro: $error, StackTrace: $stackTrace');
                        },
                      ),
                      if (_routePoints.isNotEmpty)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _routePoints,
                              color: Colors.blue,
                              strokeWidth: 5.0,
                            ),
                          ],
                        )
                      else // Opcional: Mantém a polilinha de exemplo se nenhuma rota for carregada
                        PolylineLayer(polylines: [ Polyline(points: [LatLng(0,0), LatLng(0,0)], color: Colors.transparent) ],), // Linha transparente para não quebrar
                    ],
                  ),
                  Center(
                    child: IgnorePointer(
                      child: Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 50,
                      ),
                    ),
                  ),
                ],
              ),
      floatingActionButton: FloatingActionButton(
        child: _isFetchingRoute ? CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white), key: Key("fabLoader")) : Icon(Icons.directions),
        tooltip: 'Obter Rota e Selecionar Local',
        onPressed: _isFetchingRoute ? null : () async {
            await _fetchAndDisplayRoute(); // Busca e exibe a rota

            // Após buscar a rota (ou se falhar), você pode prosseguir com a navegação
            // se o selectedPosition ainda for válido.
            if (selectedPosition != null) { // Re-verificar selectedPosition pois _fetchAndDisplayRoute é async
              print(
                'Local selecionado para navegação: ${selectedPosition!.latitude}, ${selectedPosition!.longitude}',
              );
              // Navigator.push(
              //   context,
              //   MaterialPageRoute(
              //     builder: (context) {
              //       return PickedPlace(localizacao: selectedPosition!);
              //     },
              //   ),
              // );
            } else if (userPosition != null && !_isFetchingRoute) {
                // Se selectedPosition se tornou nulo por algum motivo mas userPosition existe
                // e não estamos buscando rota, talvez alertar o usuário ou usar userPosition.
                print("selectedPosition é nulo após tentativa de rota, mas userPosition existe.");
            }
          },
      ),
    );
  }
}

  // Método de teste para inicializar com localização fixa
  // void _initializeWithFixedLocation() {
  //   print("PlacePicker: Inicializando com localização FIXA.");
  //   if (mounted) {
  //     setState(() {
  //       userPosition = LatLng(51.509865, -0.118092); // Exemplo: Londres
  //       selectedPosition = LatLng(51.509865, -0.118092);
  //       print("PlacePicker: userPosition e selectedPosition (FIXOS) atualizados.");
  //     });
  //   }
  // }
