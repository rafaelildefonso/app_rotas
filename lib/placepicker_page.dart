// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapa_teste/getUserLocation.dart';
// import 'package:mapa_teste/pickedplace_page.dart';
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

  final TextEditingController _searchController = TextEditingController();
  List<dynamic> resultadosPesquisa = [];

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

    getCurrentLocation()
        .then((position) {
          print(
            "PlacePicker: Localização obtida - Lat: ${position.latitude}, Lng: ${position.longitude}",
          );
          if (mounted) {
            // Garante que o widget ainda está na árvore
            setState(() {
              userPosition = LatLng(position.latitude, position.longitude);
              selectedPosition = LatLng(position.latitude, position.longitude);
              print(
                "PlacePicker: userPosition e selectedPosition atualizados.",
              );
            });
          }
        })
        .catchError((error) {
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
        SnackBar(
          content: Text('Defina um ponto de partida e chegada no mapa.'),
        ),
      );
      return;
    }

    if (_orsApiKey == 'CHAVE_NAO_ENCONTRADA' || _orsApiKey.isEmpty) {
      print("Chave da API do OpenRouteService não configurada.");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Chave da API do OpenRouteService não configurada.'),
        ),
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
      [selectedPosition!.longitude, selectedPosition!.latitude],
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

        final List<dynamic> coords =
            data['features'][0]['geometry']['coordinates'];
        setState(() {
          _routePoints =
              coords.map((coord) => LatLng(coord[1], coord[0])).toList();
        });
      } else {
        print(
          'Erro na API OpenRouteService: ${response.statusCode} - ${response.body}',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao buscar rota: ${response.reasonPhrase}'),
          ),
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

  Future<void> searchLocation(String endereco) async {
    final uri = Uri.https(
      'api.openrouteservice.org',
      '/geocode/search',
      {
        'text': endereco,
      }, // O parâmetro 'text' será adicionado como ?text=endereco_encodado
    );

    final response = await http.get(
      Uri.parse(uri.toString()),
      headers: {
        'Authorization': _orsApiKey,
        'Content-Type': 'application/json',
      },
      // body: jsonEncode({'text': endereco}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      List<dynamic>? features = data['features'];

      if (features != null && features.isNotEmpty) {
        setState(() {
          resultadosPesquisa.clear();

          resultadosPesquisa =
              features.map((feature) {
                return {
                  "label": feature['properties']['label'] as String,
                  "coordinates": [
                    feature['bbox'][1] as double,
                    feature['bbox'][0] as double,
                  ],
                };
              }).toList();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sem resultados para essa busca'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          userPosition == null && !_isFetchingRoute
              ? Center(
                child: CircularProgressIndicator(key: Key("initialLoader")),
              )
              : _isFetchingRoute
              ? Center(
                child: CircularProgressIndicator(key: Key("routeLoader")),
              )
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
                            resultadosPesquisa.clear();
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
                          print(
                            'Erro ao carregar tile: ${tile.coordinates}, Erro: $error, StackTrace: $stackTrace',
                          );
                        },
                      ),
                      if (userPosition != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              width: 50.0,
                              height: 50.0,
                              point: userPosition!,
                              child: PulsingCircleMarker(
                                centerCircleDiameter:
                                    15.0, // Diâmetro do ponto azul central
                                color: Color(0xff4285f4), // Cor do marcador
                                initialPulseOpacity:
                                    0.3, // Um pouco mais visível que 0.2
                                pulseScaleMultipliers: const [
                                  1.5,
                                  2.0,
                                  2.5,
                                ], // Define as ondas
                                animationDuration: const Duration(
                                  milliseconds: 1000,
                                ),
                              ),
                            ),
                          ],
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
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: [LatLng(0, 0), LatLng(0, 0)],
                              color: Colors.transparent,
                            ),
                          ],
                        ), // Linha transparente para não quebrar
                    ],
                  ),
                  Center(
                    child: IgnorePointer(
                      child: Icon(Icons.add, color: Colors.red, size: 30),
                    ),
                  ),
                  SafeArea(
                    child: SizedBox(
                      width: double.infinity,
                      height: 300,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width:
                                      MediaQuery.of(context).size.width * 0.8,
                                  child: TextField(
                                    onChanged: (text){
                                      setState(() {
                                        resultadosPesquisa.clear();
                                      });
                                    },
                                    controller: _searchController,
                                    decoration: InputDecoration(
                                      hintText: "Pesquisar localização",
                                      fillColor: Colors.white,
                                      filled: true,
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.white,
                                  ),
                                  child:
                                      _searchController.text.isEmpty
                                          ? IconButton(
                                            onPressed:
                                                _isFetchingRoute
                                                    ? null
                                                    : () async {
                                                      await _fetchAndDisplayRoute(); // Busca e exibe a rota

                                                      // Após buscar a rota (ou se falhar), você pode prosseguir com a navegação
                                                      // se o selectedPosition ainda for válido.
                                                      if (selectedPosition !=
                                                          null) {
                                                        // Re-verificar selectedPosition pois _fetchAndDisplayRoute é async
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
                                                      } else if (userPosition !=
                                                              null &&
                                                          !_isFetchingRoute) {
                                                        // Se selectedPosition se tornou nulo por algum motivo mas userPosition existe
                                                        // e não estamos buscando rota, talvez alertar o usuário ou usar userPosition.
                                                        print(
                                                          "selectedPosition é nulo após tentativa de rota, mas userPosition existe.",
                                                        );
                                                      }
                                                    },
                                            icon: Icon(Icons.directions),
                                            color: Colors.blueAccent,
                                            style: ButtonStyle(
                                              fixedSize:
                                                  WidgetStateProperty.all(
                                                    Size(50, 50),
                                                  ),
                                            ),
                                          )
                                          : IconButton(
                                            onPressed: () {
                                              if (_searchController
                                                  .text
                                                  .isNotEmpty) {
                                                searchLocation(
                                                  _searchController.text,
                                                );
                                              }
                                            },
                                            icon: Icon(Icons.search),
                                            color: Colors.blueAccent,
                                            style: ButtonStyle(
                                              fixedSize:
                                                  WidgetStateProperty.all(
                                                    Size(50, 50),
                                                  ),
                                            ),
                                          ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            if (resultadosPesquisa.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                ),
                                child: Container(
                                  // A decoração foi removida para um visual mais limpo com Cards
                                  // decoration: BoxDecoration(
                                  //   color: Colors.grey[100],
                                  //   borderRadius: BorderRadius.circular(8),
                                  // ),
                                  height: 225, // Define a altura do container da lista
                                  child: ListView.builder( // Alterado para ListView.builder
                                    itemCount: resultadosPesquisa.length,
                                    itemBuilder: (context, index) {
                                      final result = resultadosPesquisa[index];
                                      // Adicionar verificação de segurança para os dados
                                      final String? nomeEndereco = result['label'] as String?;
                                      final List<dynamic>? coords = result['coordinates'] as List<dynamic>?;

                                      // Verifica se os dados essenciais não são nulos
                                      if (nomeEndereco == null || coords == null || coords.length < 2 || coords[0] == null || coords[1] == null) {
                                        // Log para debug e retorna um widget vazio para não quebrar a UI
                                        print("Dados inválidos para o item $index: $result");
                                        return SizedBox.shrink(); 
                                      }

                                      // Converte as coordenadas para double de forma segura
                                      LatLng coordenada = LatLng(
                                        (coords[0] as num).toDouble(),
                                        (coords[1] as num).toDouble(),
                                      );

                                      return Card(
                                        margin: const EdgeInsets.symmetric(vertical: 2.0),
                                        elevation: 2.0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8.0),
                                        ),
                                        child: ListTile(
                                          leading: Icon(
                                            Icons.location_on_outlined,
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                          title: Text(
                                            nomeEndereco,
                                            style: TextStyle(fontWeight: FontWeight.w500),
                                          ),
                                          contentPadding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                                          onTap: () {
                                            setState(() {
                                              selectedPosition = coordenada;
                                              _mapController.move(coordenada, _mapController.camera.zoom);
                                              resultadosPesquisa.clear();
                                              _searchController.clear();
                                            });
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
    );
  }
}

// Widget para o marcador pulsante
class PulsingCircleMarker extends StatefulWidget {
  final double centerCircleDiameter; // Diâmetro do círculo central
  final Color color;
  final Duration animationDuration;
  final double initialPulseOpacity;
  final List<double> pulseScaleMultipliers; // e.g., [1.0, 1.5, 2.0]

  const PulsingCircleMarker({
    Key? key,
    this.centerCircleDiameter = 20.0, // Padrão para o círculo central
    this.color = Colors.blue,
    this.animationDuration = const Duration(
      seconds: 1,
    ), // Duração da animação SwiftUI
    this.initialPulseOpacity =
        0.2, // Opacidade inicial do pulso (como no SwiftUI)
    this.pulseScaleMultipliers = const [
      1.0,
      1.75,
      2.5,
    ], // Escalas para os pulsos
  }) : super(key: key);

  @override
  _PulsingCircleMarkerState createState() => _PulsingCircleMarkerState();
}

class _PulsingCircleMarkerState extends State<PulsingCircleMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    )..repeat(); // Inicia a animação em loop
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        double animationProgress =
            _animationController.value; // Vai de 0.0 a 1.0
        // Opacidade do pulso diminui de initialPulseOpacity para 0
        double currentPulseOpacity =
            widget.initialPulseOpacity * (1.0 - animationProgress);

        // Cria os círculos pulsantes
        List<Widget> pulseCircles =
            widget.pulseScaleMultipliers.map((scaleMultiplier) {
              return _buildPulsingCircle(
                animationProgress,
                scaleMultiplier,
                widget.centerCircleDiameter, // Diâmetro base para os pulsos
                currentPulseOpacity,
                widget.color,
              );
            }).toList();

        return Stack(
          alignment: Alignment.center,
          children: <Widget>[
            ...pulseCircles, // Adiciona os círculos pulsantes (os maiores ficam atrás)
            // Círculo central fixo
            Container(
              width: widget.centerCircleDiameter,
              height: widget.centerCircleDiameter,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
                // Opcional: Adicionar uma borda branca para destacar
                // border: Border.all(color: Colors.white.withOpacity(0.7), width: 1.5),
              ),
            ),
          ],
        );
      },
    );
  }

  // Helper para construir cada círculo pulsante
  Widget _buildPulsingCircle(
    double animationProgress,
    double
    targetScaleMultiplier, // Escala alvo para este pulso (ex: 1.0, 1.5, 2.0)
    double baseDiameter, // Diâmetro base do círculo antes de escalar
    double opacity, // Opacidade atual do pulso
    Color color, // Cor do pulso
  ) {
    // A escala atual vai de 0 até targetScaleMultiplier conforme a animação progride
    double currentScale = animationProgress * targetScaleMultiplier;

    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: currentScale,
        child: Container(
          width: baseDiameter,
          height: baseDiameter,
          decoration: BoxDecoration(
            color: color, // Cor do pulso (a mesma do círculo central)
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
