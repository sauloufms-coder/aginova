import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// Multiseleção (usaremos quando já houver opções)
import 'package:multi_select_flutter/multi_select_flutter.dart';

// Export/Share (mobile/desktop)
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cross_file/cross_file.dart';

// Download no Web
import 'package:universal_html/html.dart' as html;

/// ====== CONFIG ======
const String API_BASE = String.fromEnvironment(
  'API_BASE',
  defaultValue:
      'https://script.google.com/macros/s/AKfycbwBX8ZkThfg8kQwVmKyJt1leb2CXkMty8iOwQmilZn6xCGKY-cKccaHo_VYobW-uDpAZg/exec',
);

const String API_KEY =
    String.fromEnvironment('API_KEY', defaultValue: 's123g456m789');

const int PAGE_SIZE = 50;

void main() {
  Intl.defaultLocale = 'pt_BR';
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    final seedBlue = Colors.blue.shade700;
    return MaterialApp(
      title: 'Sistema de Gestão de Parcerias - Aginova - UFMS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seedBlue),
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          backgroundColor: seedBlue,
          foregroundColor: Colors.white,
          elevation: 1,
        ),
        chipTheme: ChipThemeData(
          color: WidgetStatePropertyAll(Colors.blue.shade50),
          labelStyle: const TextStyle(color: Colors.black87),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const DemandasHome(),
    );
  }
}

/// ====== MODELOS ======

class ApiPage {
  final int count;
  final int page;
  final int pageSize;
  final String orderBy;
  final String orderDir;
  final List<Demanda> data;

  ApiPage({
    required this.count,
    required this.page,
    required this.pageSize,
    required this.orderBy,
    required this.orderDir,
    required this.data,
  });

  factory ApiPage.fromJson(Map<String, dynamic> j) => ApiPage(
        count: j['count'] ?? 0,
        page: j['page'] ?? 1,
        pageSize: j['pageSize'] ?? PAGE_SIZE,
        orderBy: j['orderBy'] ?? 'ultima_atualizacao_status',
        orderDir: j['orderDir'] ?? 'desc',
        data: (j['data'] as List? ?? [])
            .map((e) => Demanda.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class Demanda {
  final String id;
  final String? descricao;
  final String? unidade;
  final String? instrumentoJuridico;
  final String? tipo;
  final String? status;
  final String? numeroProcessoSei;
  final String? processoSei;
  final String? servidorResponsavel;
  final String? coordenador;
  final String? instituicaoParceira;
  final double? valor;
  final int? vigenciaMeses;
  final String? ultimaAtualizacaoIso;

  Demanda({
    required this.id,
    this.descricao,
    this.unidade,
    this.instrumentoJuridico,
    this.tipo,
    this.status,
    this.numeroProcessoSei,
    this.processoSei,
    this.servidorResponsavel,
    this.coordenador,
    this.instituicaoParceira,
    this.valor,
    this.vigenciaMeses,
    this.ultimaAtualizacaoIso,
  });

  factory Demanda.fromJson(Map<String, dynamic> j) => Demanda(
        id: (j['id'] ?? '').toString(),
        descricao: _s(j['descricao']),
        unidade: _s(j['unidade']),
        instrumentoJuridico: _s(j['instrumento_juridico']),
        tipo: _s(j['tipo']),
        status: _s(j['status']),
        numeroProcessoSei: _s(j['numero_processo_sei']),
        processoSei: _s(j['processo_sei']),
        servidorResponsavel: _s(j['servidor_responsavel']),
        coordenador: _s(j['coordenador']),
        instituicaoParceira: _s(j['instituicao_parceira']),
        valor: _d(j['valor']),
        vigenciaMeses: _i(j['vigencia_meses']),
        ultimaAtualizacaoIso: _s(j['ultima_atualizacao_status']),
      );
}

String? _s(dynamic v) => v == null ? null : v.toString();
double? _d(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  final s = v.toString().replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(s);
}
int? _i(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

/// ====== FILTROS ======

class Filtros {
  String q = '';
  double? valorMin, valorMax;
  int? vigenciaMin, vigenciaMax;

  // Multiseleções
  final List<String> tipos = [];
  final List<String> instrumentos = [];
  final List<String> unidades = [];
  final List<String> status = [];
  final List<String> servidores = [];
  final List<String> coordenadores = [];
  final List<String> parceiros = [];

  Map<String, String> toQuery() {
    final Map<String, String> p = {
      'key': API_KEY,
      'pageSize': PAGE_SIZE.toString(),
      'orderBy': 'ultima_atualizacao_status',
      'orderDir': 'desc',
    };
    if (q.trim().isNotEmpty) p['q'] = q.trim();

    if (valorMin != null) p['valor_min'] = _normalizeNum(valorMin!);
    if (valorMax != null) p['valor_max'] = _normalizeNum(valorMax!);

    if (vigenciaMin != null) p['vigencia_min'] = vigenciaMin.toString();
    if (vigenciaMax != null) p['vigencia_max'] = vigenciaMax.toString();

    void addIn(String key, List<String> list) {
      if (list.isNotEmpty) p[key] = list.join(',');
    }

    addIn('tipo_in', tipos);
    addIn('instrumento_juridico_in', instrumentos);
    addIn('unidade_in', unidades);
    addIn('status_in', status);
    addIn('servidor_responsavel_in', servidores);
    addIn('coordenador_in', coordenadores);
    addIn('instituicao_parceira_in', parceiros);

    return p;
  }

  String _normalizeNum(double v) {
    final br = NumberFormat('0.##', 'pt_BR').format(v);
    return br.replaceAll('.', '').replaceAll(',', '.');
  }

  void clearAll() {
    q = '';
    valorMin = valorMax = null;
    vigenciaMin = vigenciaMax = null;
    tipos.clear();
    instrumentos.clear();
    unidades.clear();
    status.clear();
    servidores.clear();
    coordenadores.clear();
    parceiros.clear();
  }
}

/// ====== API CLIENT ======

class ApiClient {
  final String base;
  final String key;
  ApiClient({required this.base, required this.key});

  Future<ApiPage> fetchPage(Filtros f, int page) async {
    final uri = Uri.parse(base).replace(
      queryParameters: {
        ...f.toQuery(),
        'page': page.toString(),
      },
    );
    final resp = await http.get(uri);
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
    final j = jsonDecode(resp.body) as Map<String, dynamic>;
    if (j['error'] == 'unauthorized') {
      throw Exception('API key inválida');
    }
    return ApiPage.fromJson(j);
  }

  /// Tenta obter opções pelo `diag=1`. Caso não venha nada, faz fallback:
  /// busca até 500 registros e monta conjuntos distintos localmente.
  Future<Map<String, List<String>>> getOptions() async {
    // 1) diag=1
    try {
      final uri = Uri.parse(base).replace(
        queryParameters: {'key': key, 'diag': '1'},
      );
      final resp = await http.get(uri);
      if (resp.statusCode == 200) {
        final j = jsonDecode(resp.body);
        if (j is Map && j['opts'] is Map) {
          final o = (j['opts'] as Map).map((k, v) {
            final list =
                (v as List?)?.map((e) => e.toString()).toList() ?? <String>[];
            list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
            return MapEntry(k.toString(), list);
          });
          final typed = o.map((k, v) => MapEntry(k, v.cast<String>()));
          final some = typed.values.any((l) => l.isNotEmpty);
          if (some) return typed;
        }
      }
    } catch (_) {
      // continua para fallback
    }

    // 2) fallback: pega até 500 registros e cria as listas distintas
    try {
      final uri = Uri.parse(base).replace(
        queryParameters: {
          'key': key,
          'page': '1',
          'pageSize': '500',
          'orderBy': 'ultima_atualizacao_status',
          'orderDir': 'desc',
        },
      );
      final resp = await http.get(uri);
      if (resp.statusCode != 200) return {};
      final j = jsonDecode(resp.body) as Map<String, dynamic>;
      final data = (j['data'] as List? ?? [])
          .map((e) => Demanda.fromJson(e as Map<String, dynamic>))
          .toList();

      final setTipo = <String>{};
      final setInst = <String>{};
      final setUnid = <String>{};
      final setStatus = <String>{};
      final setServ = <String>{};
      final setCoord = <String>{};
      final setParc = <String>{};

      for (final d in data) {
        if ((d.tipo ?? '').trim().isNotEmpty) setTipo.add(d.tipo!.trim());
        if ((d.instrumentoJuridico ?? '').trim().isNotEmpty) {
          setInst.add(d.instrumentoJuridico!.trim());
        }
        if ((d.unidade ?? '').trim().isNotEmpty) setUnid.add(d.unidade!.trim());
        if ((d.status ?? '').trim().isNotEmpty) setStatus.add(d.status!.trim());
        if ((d.servidorResponsavel ?? '').trim().isNotEmpty) {
          setServ.add(d.servidorResponsavel!.trim());
        }
        if ((d.coordenador ?? '').trim().isNotEmpty) {
          setCoord.add(d.coordenador!.trim());
        }
        if ((d.instituicaoParceira ?? '').trim().isNotEmpty) {
          setParc.add(d.instituicaoParceira!.trim());
        }
      }

      List<String> _sorted(Set<String> s) {
        final l = s.toList();
        l.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        return l;
      }

      return {
        'tipo': _sorted(setTipo),
        'instrumento_juridico': _sorted(setInst),
        'unidade': _sorted(setUnid),
        'status': _sorted(setStatus),
        'servidor_responsavel': _sorted(setServ),
        'coordenador': _sorted(setCoord),
        'instituicao_parceira': _sorted(setParc),
      };
    } catch (_) {
      return {};
    }
  }

  /// Busca tudo (pagineando) — usado na Exportação CSV
  Future<List<Demanda>> fetchAll(Filtros f) async {
    int page = 1;
    final List<Demanda> out = [];
    while (true) {
      final p = await fetchPage(f, page);
      out.addAll(p.data);
      final fetched = p.page * p.pageSize;
      if (fetched >= p.count || p.data.isEmpty) break;
      page++;
    }
    return out;
  }
}

/// ====== HOME ======

class DemandasHome extends StatefulWidget {
  const DemandasHome({super.key});
  @override
  State<DemandasHome> createState() => _DemandasHomeState();
}

class _DemandasHomeState extends State<DemandasHome> {
  final api = ApiClient(base: API_BASE, key: API_KEY);
  final filtros = Filtros();

  final ScrollController _scroll = ScrollController();

  final List<Demanda> _items = [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  int _total = 0;

  // Opções
  List<String> _optTipos = [];
  List<String> _optInstrumentos = [];
  List<String> _optUnidades = [];
  List<String> _optStatus = [];
  List<String> _optServidores = [];
  List<String> _optCoordenadores = [];
  List<String> _optParceiros = [];

  // controles
  final TextEditingController _q = TextEditingController();
  final TextEditingController _valorMin = TextEditingController();
  final TextEditingController _valorMax = TextEditingController();
  final TextEditingController _vigMin = TextEditingController();
  final TextEditingController _vigMax = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _bootstrap();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    try {
      final opts = await api.getOptions();
      setState(() {
        _optTipos = (opts['tipo'] ?? []);
        _optInstrumentos = (opts['instrumento_juridico'] ?? []);
        _optUnidades = (opts['unidade'] ?? []);
        _optStatus = (opts['status'] ?? []);
        _optServidores = (opts['servidor_responsavel'] ?? []);
        _optCoordenadores = (opts['coordenador'] ?? []);
        _optParceiros = (opts['instituicao_parceira'] ?? []);
      });
      await _reload();
    } catch (e) {
      _snack('Falha ao iniciar: $e');
      await _reload(); // mesmo sem opções, permite busca textual
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _items.clear();
      _page = 1;
      _hasMore = true;
      _total = 0;
    });
    try {
      final p = await api.fetchPage(filtros, _page);
      setState(() {
        _items.addAll(p.data);
        _total = p.count;
        _hasMore = (_page * p.pageSize) < p.count;
      });
    } catch (e) {
      _snack('Erro ao carregar: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final next = _page + 1;
      final p = await api.fetchPage(filtros, next);
      setState(() {
        _page = next;
        _items.addAll(p.data);
        _hasMore = (_page * p.pageSize) < p.count;
        _total = p.count;
      });
    } catch (e) {
      _snack('Erro ao carregar mais: $e');
    } finally {
      setState(() => _loadingMore = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    // ignore: avoid_print
    print(msg);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _q.dispose();
    _valorMin.dispose();
    _valorMax.dispose();
    _vigMin.dispose();
    _vigMax.dispose();
    super.dispose();
  }

  /// ========== UI ==========

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Sistema de Gestão de Parcerias - Aginova - UFMS',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Exportar CSV (todos os resultados do filtro)',
            onPressed: _onExport,
            icon: const Icon(Icons.download),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildFiltersCard(),
          _buildSummaryBar(),
          const Divider(height: 1),
          Expanded(child: _buildList()),
          if (_loadingMore)
            const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar() {
    return Container(
      color: Colors.blue.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Text('Total: $_total'),
          const SizedBox(width: 16),
          if (_loading) const Text('Carregando…'),
          if (!_loading && _items.isNotEmpty) Text('Exibindo ${_items.length}'),
        ],
      ),
    );
  }

  Widget _buildFiltersCard() {
    return Material(
      elevation: 1,
      child: Container(
        color: Colors.blue.shade100.withOpacity(0.25),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _q,
                    decoration: const InputDecoration(
                      labelText:
                          'Buscar (descrição, unidade, instrumento, SEI...)',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _applyText(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _applyText,
                  icon: const Icon(Icons.filter_alt),
                  label: const Text('Aplicar'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _clearAll,
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Limpar'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              runSpacing: 8,
              spacing: 8,
              children: [
                _numField('Valor (R\\\$) mín', _valorMin, (v) {
                  filtros.valorMin = v;
                }),
                _numField('Valor (R\\\$) máx', _valorMax, (v) {
                  filtros.valorMax = v;
                }),
                _intField('Vigência (meses) mín', _vigMin, (v) {
                  filtros.vigenciaMin = v;
                }),
                _intField('Vigência (meses) máx', _vigMax, (v) {
                  filtros.vigenciaMax = v;
                }),
              ],
            ),
            const SizedBox(height: 10),

            // === Multi seleções (agora sempre clicáveis, com fallback) ===
            Wrap(
              runSpacing: 8,
              spacing: 8,
              children: [
                _multi('Tipo', () => _optTipos, filtros.tipos),
                _multi('Instrumento jurídico',
                    () => _optInstrumentos, filtros.instrumentos),
                _multi('Unidade', () => _optUnidades, filtros.unidades,
                    width: 300),
                _multi('Status', () => _optStatus, filtros.status),
                _multi('Coordenador', () => _optCoordenadores, filtros.coordenadores,
                    width: 280),
                _multi('Servidor responsável',
                    () => _optServidores, filtros.servidores,
                    width: 280),
                _multi('Instituição parceira',
                    () => _optParceiros, filtros.parceiros,
                    width: 320),
              ],
            ),

            const SizedBox(height: 8),
            // === Feedback + Recarregar opções ===
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  (_optTipos.isEmpty &&
                          _optInstrumentos.isEmpty &&
                          _optUnidades.isEmpty &&
                          _optStatus.isEmpty &&
                          _optServidores.isEmpty &&
                          _optCoordenadores.isEmpty &&
                          _optParceiros.isEmpty)
                      ? 'Opções ainda não carregadas'
                      : 'Opções carregadas',
                  style: TextStyle(color: Colors.blue.shade700),
                ),
                TextButton.icon(
                  onPressed: () async {
                    setState(() => _loading = true);
                    try {
                      final opts = await api.getOptions();
                      setState(() {
                        _optTipos = (opts['tipo'] ?? []);
                        _optInstrumentos = (opts['instrumento_juridico'] ?? []);
                        _optUnidades = (opts['unidade'] ?? []);
                        _optStatus = (opts['status'] ?? []);
                        _optServidores = (opts['servidor_responsavel'] ?? []);
                        _optCoordenadores = (opts['coordenador'] ?? []);
                        _optParceiros = (opts['instituicao_parceira'] ?? []);
                      });
                      _snack('Opções recarregadas.');
                    } catch (e) {
                      _snack('Falha ao recarregar opções: $e');
                    } finally {
                      setState(() => _loading = false);
                    }
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Recarregar opções'),
                ),
              ],
            ),

            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
                label: const Text('Recarregar lista'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numField(
    String label,
    TextEditingController ctl,
    void Function(double?) onChanged, {
    double width = 180,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: ctl,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true, signed: false),
        onChanged: (s) {
          final norm = s.replaceAll('.', '').replaceAll(',', '.');
          onChanged(double.tryParse(norm));
        },
      ),
    );
  }

  Widget _intField(
    String label,
    TextEditingController ctl,
    void Function(int?) onChanged, {
    double width = 200,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: ctl,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        keyboardType: TextInputType.number,
        onChanged: (s) => onChanged(int.tryParse(s)),
      ),
    );
  }

  /// BOTÃO DE MULTI-SELEÇÃO SEMPRE CLICÁVEL
  /// - Se já houver opções, usa MultiSelectDialogField
  /// - Se não houver, busca opções e abre um diálogo customizado (fallback)
  Widget _multi(
    String label,
    List<String> Function() optionsProvider,
    List<String> selected, {
    double width = 220,
  }) {
    final options = optionsProvider();
    if (options.isNotEmpty) {
      final items =
          options.map((e) => MultiSelectItem<String>(e, e)).toList(growable: false);
      return SizedBox(
        width: width,
        child: MultiSelectDialogField<String>(
          items: items,
          initialValue: List<String>.from(selected),
          searchable: true,
          title: Text(label),
          buttonText: Text(label),
          buttonIcon: const Icon(Icons.arrow_drop_down),
          dialogWidth: 420,
          chipDisplay: MultiSelectChipDisplay(
            onTap: (val) {
              setState(() => selected.remove(val));
              _reload();
            },
          ),
          listType: MultiSelectListType.LIST,
          onConfirm: (vals) {
            setState(() {
              selected
                ..clear()
                ..addAll(vals);
            });
            _reload();
          },
        ),
      );
    }

    // FALLBACK: sem opções → botão que busca e abre um dialog customizado
    return SizedBox(
      width: width,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.list_alt),
        label: Text(label),
        onPressed: () async {
          setState(() => _loading = true);
          try {
            // tenta recarregar as opções
            final opts = await api.getOptions();
            setState(() {
              _optTipos = (opts['tipo'] ?? _optTipos);
              _optInstrumentos = (opts['instrumento_juridico'] ?? _optInstrumentos);
              _optUnidades = (opts['unidade'] ?? _optUnidades);
              _optStatus = (opts['status'] ?? _optStatus);
              _optServidores = (opts['servidor_responsavel'] ?? _optServidores);
              _optCoordenadores = (opts['coordenador'] ?? _optCoordenadores);
              _optParceiros = (opts['instituicao_parceira'] ?? _optParceiros);
            });
          } catch (e) {
            _snack('Não foi possível carregar opções: $e');
          } finally {
            setState(() => _loading = false);
          }

          final refreshed = optionsProvider();
          await _openCustomMultiDialog(label, refreshed, selected);
        },
      ),
    );
  }

  Future<void> _openCustomMultiDialog(
    String label,
    List<String> options,
    List<String> selected,
  ) async {
    final Set<String> temp = {...selected};
    await showDialog(
      context: context,
      builder: (ctx) {
        final filtered = ValueNotifier<List<String>>(options);
        final searchCtl = TextEditingController();
        return AlertDialog(
          title: Text(label),
          content: SizedBox(
            width: 420,
            height: 420,
            child: Column(
              children: [
                TextField(
                  controller: searchCtl,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                    labelText: 'Pesquisar',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (s) {
                    final q = s.trim().toLowerCase();
                    filtered.value = q.isEmpty
                        ? options
                        : options
                            .where((e) => e.toLowerCase().contains(q))
                            .toList();
                  },
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ValueListenableBuilder<List<String>>(
                    valueListenable: filtered,
                    builder: (_, list, __) {
                      if (list.isEmpty) {
                        return const Center(child: Text('Sem opções'));
                      }
                      return Scrollbar(
                        thumbVisibility: true,
                        child: ListView.builder(
                          itemCount: list.length,
                          itemBuilder: (_, i) {
                            final v = list[i];
                            final checked = temp.contains(v);
                            return CheckboxListTile(
                              dense: true,
                              value: checked,
                              title: Text(v),
                              onChanged: (ok) {
                                if (ok == true) {
                                  temp.add(v);
                                } else {
                                  temp.remove(v);
                                }
                                // força rebuild do dialog
                                (ctx as Element).markNeedsBuild();
                              },
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                setState(() {
                  selected
                    ..clear()
                    ..addAll(temp);
                });
                Navigator.of(ctx).pop();
                _reload();
              },
              child: const Text('Aplicar'),
            ),
          ],
        );
      },
    );
  }

  void _applyText() {
    filtros.q = _q.text.trim();
    _reload();
  }

  void _clearAll() {
    _q.clear();
    _valorMin.clear();
    _valorMax.clear();
    _vigMin.clear();
    _vigMax.clear();
    setState(() => filtros.clearAll());
    _reload();
  }

  Widget _buildList() {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return const Center(child: Text('Sem resultados'));
    }

    return ListView.separated(
      controller: _scroll,
      itemCount: _items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final d = _items[i];
        return ListTile(
          title: Text(
            d.descricao ?? '(Sem descrição)',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              if (d.unidade != null) _kv('Unidade', d.unidade!),
              if (d.instrumentoJuridico != null)
                _kv('Instrumento', d.instrumentoJuridico!),
              if (d.tipo != null) _kv('Tipo', d.tipo!),
              if (d.status != null) _kv('Status', d.status!),
              if (d.valor != null) _kv('Valor', _formatBRL(d.valor!)),
              if (d.vigenciaMeses != null)
                _kv('Vigência', '${d.vigenciaMeses} meses'),
              if (d.numeroProcessoSei != null)
                _kv('Nº SEI', d.numeroProcessoSei!),
              if (d.servidorResponsavel != null)
                _kv('Servidor', d.servidorResponsavel!),
              if (d.coordenador != null) _kv('Coordenador', d.coordenador!),
              if (d.instituicaoParceira != null)
                _kv('Parceiro', d.instituicaoParceira!),
              if (d.ultimaAtualizacaoIso != null)
                _kv('Atualizado', _formatIso(d.ultimaAtualizacaoIso!)),
            ],
          ),
          trailing: Text(
            d.id,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          isThreeLine: true,
        );
      },
    );
  }

  Widget _kv(String k, String v) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$k: $v', style: const TextStyle(fontSize: 12)),
    );
  }

  String _formatBRL(double v) {
    final f = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    return f.format(v);
  }

  String _formatIso(String iso) {
    try {
      final d = DateTime.parse(iso);
      return DateFormat('dd/MM/yyyy HH:mm').format(d);
    } catch (_) {
      return iso;
    }
  }

  Future<void> _onExport() async {
    try {
      _snack('Preparando exportação…');
      final all = await api.fetchAll(filtros);
      final csv = _toCsv(all);
      final bytes = Uint8List.fromList(utf8.encode(csv));
      const fileName = 'demandas.csv';

      if (kIsWeb) {
        final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
        _snack('CSV baixado.');
      } else {
        final dir = await getTemporaryDirectory();
        final file = await File('${dir.path}/$fileName').writeAsBytes(bytes);
        await Share.shareXFiles([XFile(file.path)], text: 'Exportação de demandas');
      }
    } catch (e) {
      _snack('Falha ao exportar: $e');
    }
  }

  String _toCsv(List<Demanda> list) {
    final cols = <String>[
      'id',
      'descricao',
      'unidade',
      'instrumento_juridico',
      'tipo',
      'status',
      'valor',
      'vigencia_meses',
      'numero_processo_sei',
      'processo_sei',
      'servidor_responsavel',
      'coordenador',
      'instituicao_parceira',
      'ultima_atualizacao_status',
    ];
    final buf = StringBuffer();
    buf.writeln(cols.map(_csvEsc).join(','));
    for (final d in list) {
      final row = [
        d.id,
        d.descricao,
        d.unidade,
        d.instrumentoJuridico,
        d.tipo,
        d.status,
        d.valor?.toString(),
        d.vigenciaMeses?.toString(),
        d.numeroProcessoSei,
        d.processoSei,
        d.servidorResponsavel,
        d.coordenador,
        d.instituicaoParceira,
        d.ultimaAtualizacaoIso,
      ];
      buf.writeln(row.map(_csvEsc).join(','));
    }
    return buf.toString();
  }

  String _csvEsc(String? v) {
    final s = (v ?? '').replaceAll('\r', ' ').replaceAll('\n', ' ').trim();
    final needsQuote = s.contains(',') || s.contains('"') || s.contains(';');
    if (needsQuote) return '"${s.replaceAll('"', '""')}"';
    return s;
  }
}

