import 'package:flutter/material.dart';

import 'ai_context_service.dart';
import 'ai_assistant_service.dart';

enum AiIntent {
  greeting,
  help,
  order,
  critical,
  lowStock,
  depletion,
  risk,
  health,
  consumption,
  history,
  orders,
  box,
  forecast,
  recommendation,
  summary,
  unknown,
}

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  static const darkBlue = Color(0xFF061E29);
  static const midBlue = Color(0xFF1D546D);
  static const teal = Color(0xFF5F9598);
  static const light = Color(0xFFF3F4F4);

  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _contextService = AiContextService();
  final _assistantService = AiAssistantService();

  final List<_ChatMessage> _messages = [
    _ChatMessage(
      text:
      'Salut! Sunt AI Assistant pentru StockIQ. Pot analiza stocuri, comenzi, riscuri, consum, istoric și recomandări din Firebase.',
      isUser: false,
    ),
  ];

  AiIntent? _lastIntent;
  String? _lastQuestion;
  bool _loading = false;

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  Color get bg => isDark ? darkBlue : light;
  Color get cardBg => isDark ? const Color(0xFF0F3244) : Colors.white;
  Color get headerBg => isDark ? const Color(0xFF08263A) : Colors.white;
  Color get textColor => isDark ? light : darkBlue;
  Color get mutedColor =>
      isDark ? light.withOpacity(0.55) : darkBlue.withOpacity(0.48);
  Color get border =>
      isDark ? teal.withOpacity(0.20) : midBlue.withOpacity(0.13);

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final question = _controller.text.trim();

    if (question.isEmpty || _loading) return;

    setState(() {
      _messages.add(_ChatMessage(text: question, isUser: true));
      _loading = true;
      _controller.clear();
    });

    _scrollToBottom();

    try {
      final warehouseContext = await _contextService.buildWarehouseContext();

      final answer = await _assistantService.askStockAssistant(
        question: question,
        warehouseContext: warehouseContext,
      );

      if (!mounted) return;

      setState(() {
        _messages.add(
          _ChatMessage(
            text: answer,
            isUser: false,
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _messages.add(
          _ChatMessage(
            text:
            'Nu am putut primi un răspuns de la AI Assistant.\n\nDetalii: ${e.toString().replaceFirst('Exception: ', '')}',
            isUser: false,
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _scrollToBottom();
      }
    }
  }  AiIntent _detectIntent(String question) {
    final q = question.toLowerCase();

    if (_containsAny(q, ['salut', 'bună', 'buna', 'hello', 'hei'])) {
      return AiIntent.greeting;
    }

    if (_containsAny(q, ['ajutor', 'ce poți', 'ce poti', 'help'])) {
      return AiIntent.help;
    }

    if (_containsAny(q, ['comand', 'cumpăr', 'cumpar', 'reaprovizion'])) {
      return AiIntent.order;
    }

    if (_containsAny(q, ['critic', 'urgent', 'roșu', 'rosu'])) {
      return AiIntent.critical;
    }

    if (_containsAny(q, ['scăzut', 'scazut', 'low', 'galben'])) {
      return AiIntent.lowStock;
    }

    if (_containsAny(q, ['termin', 'epuiz', 'golește', 'goleste', 'primul'])) {
      return AiIntent.depletion;
    }

    if (_containsAny(q, ['risc', 'risk', 'periculos'])) {
      return AiIntent.risk;
    }

    if (_containsAny(q, ['health', 'sănătate', 'sanatate', 'stare depozit'])) {
      return AiIntent.health;
    }

    if (_containsAny(q, ['consum', 'rotație', 'rotatie', 'folosește', 'foloseste'])) {
      return AiIntent.consumption;
    }

    if (_containsAny(q, ['istoric', 'fără istoric', 'fara istoric', 'date insuficiente'])) {
      return AiIntent.history;
    }

    if (_containsAny(q, ['comenzi', 'neprocesate', 'deschise', 'în curs', 'in curs'])) {
      return AiIntent.orders;
    }

    if (_containsAny(q, ['box', 'cutie', 'cutia'])) {
      return AiIntent.box;
    }

    if (_containsAny(q, ['forecast', 'predicție', 'predictie', '7 zile', 'următoare'])) {
      return AiIntent.forecast;
    }

    if (_containsAny(q, ['recomand', 'strategie', 'ce fac', 'sfat'])) {
      return AiIntent.recommendation;
    }

    if (_containsAny(q, ['rezum', 'situa', 'raport', 'analiz'])) {
      return AiIntent.summary;
    }

    if (_containsAny(q, ['de ce', 'explică', 'explica']) && _lastIntent != null) {
      return _lastIntent!;
    }

    return AiIntent.unknown;
  }

  bool _containsAny(String text, List<String> words) {
    return words.any((w) => text.contains(w));
  }

  String _buildLocalAnswer(String question, String context) {
    final intent = _detectIntent(question);
    _lastIntent = intent;
    _lastQuestion = question;

    switch (intent) {
      case AiIntent.greeting:
        return 'Salut! Pot analiza depozitul StockIQ folosind datele din Firebase.\n\nPoți întreba: „Ce trebuie comandat?”, „Ce produs se termină primul?” sau „Rezumă situația depozitului.”';

      case AiIntent.help:
        return 'Pot răspunde la întrebări despre produse critice, stocuri scăzute, comenzi, risc, consum, istoric, cutii și recomandări.\n\n$context';

      case AiIntent.order:
        return 'Pentru comandă, prioritizez produsele critice, produsele cu stoc scăzut și produsele care se pot epuiza în curând.\n\n$context';

      case AiIntent.critical:
        return 'Produsele critice sunt cele aflate sub pragul roșu. Acestea trebuie verificate și comandate primele.\n\n$context';

      case AiIntent.lowStock:
        return 'Produsele cu stoc scăzut sunt cele aflate sub pragul galben. Ele trebuie urmărite și reaprovizionate înainte să devină critice.\n\n$context';

      case AiIntent.depletion:
        return 'Produsul care se termină primul este estimat după consumul mediu și zilele rămase până la epuizare.\n\n$context';

      case AiIntent.risk:
        return 'Scorul de risc este calculat din stocul actual, praguri, consum mediu și estimarea de epuizare.\n\n$context';

      case AiIntent.health:
        return 'Starea depozitului se interpretează după produse OK, produse scăzute, produse critice, comenzi deschise și istoric disponibil.\n\n$context';

      case AiIntent.consumption:
        return 'Consumul mediu este calculat din istoricul stockHistory, folosind scăderile de stoc din ultimele 14 zile.\n\n$context';

      case AiIntent.history:
        return 'Produsele fără istoric suficient nu pot avea predicții foarte precise. Pentru ele trebuie colectate mai multe zile în stockHistory.\n\n$context';

      case AiIntent.orders:
        return 'Comenzile deschise sunt cele cu status nou sau în curs. Ele indică produse deja cerute pentru reaprovizionare.\n\n$context';

      case AiIntent.box:
        return 'Pot analiza cutiile conectate la produse și stocul curent citit din Firebase.\n\n$context';

      case AiIntent.forecast:
        return 'Forecast-ul se bazează pe consumul mediu și stocul actual. Dacă nu există istoric suficient, predicția poate fi limitată.\n\n$context';

      case AiIntent.recommendation:
        return 'Recomandarea mea este să verifici întâi produsele critice, apoi produsele cu risc mare și apoi produsele fără istoric suficient.\n\n$context';

      case AiIntent.summary:
        return 'Rezumat inteligent al depozitului:\n\n$context';

      case AiIntent.unknown:
        return 'Am analizat întrebarea și datele disponibile din Firebase. Momentan răspund local, pe baza contextului calculat în aplicație.\n\n$context';
    }
  }

  void _askPreset(String text) {
    _controller.text = text;
    _send();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSuggestions(),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_loading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_loading && index == _messages.length) {
                    return _buildTyping();
                  }

                  return _buildMessage(_messages[index]);
                },
              ),
            ),
            _buildInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      decoration: BoxDecoration(
        color: headerBg,
        border: Border(
          bottom: BorderSide(color: border),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_rounded, color: textColor),
          ),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: teal.withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.smart_toy_rounded, color: teal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Assistant',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Asistent inteligent pentru depozit',
                  style: TextStyle(
                    color: mutedColor,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    final items = [
      'Ce trebuie comandat?',
      'Ce produs se termină primul?',
      'Ce produse sunt critice?',
      'Ce comenzi sunt deschise?',
      'Ce produse nu au istoric?',
      'Rezumă situația depozitului.',
    ];

    return SizedBox(
      height: 54,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          return GestureDetector(
            onTap: () => _askPreset(items[index]),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: border),
              ),
              alignment: Alignment.center,
              child: Text(
                items[index],
                style: TextStyle(
                  color: textColor,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessage(_ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        constraints: const BoxConstraints(maxWidth: 310),
        decoration: BoxDecoration(
          color: message.isUser ? midBlue : cardBg,
          borderRadius: BorderRadius.circular(20),
          border: message.isUser ? null : Border.all(color: border),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.isUser ? Colors.white : textColor,
            fontSize: 14,
            height: 1.35,
          ),
        ),
      ),
    );
  }

  Widget _buildTyping() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Text(
          'Analizez datele din Firebase...',
          style: TextStyle(
            color: mutedColor,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: headerBg,
        border: Border(
          top: BorderSide(color: border),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 4,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Întreabă despre stocuri...',
                hintStyle: TextStyle(color: mutedColor),
                filled: true,
                fillColor: cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: teal),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _send,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _loading ? teal.withOpacity(0.35) : teal,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;

  _ChatMessage({
    required this.text,
    required this.isUser,
  });
}