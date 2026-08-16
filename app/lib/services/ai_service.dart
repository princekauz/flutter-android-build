import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:intl/intl.dart';

/// A helper service to interact with QuillBot AI Chat headlessly via direct API fetch.
class QuillBotService {
  late final WebViewController _controller;

  Completer<String>? _responseCompleter;
  bool _isPageLoaded = false;
  bool _isInitialized = false;

  QuillBotService() {
    // Defer initialization until explicitly called or accessed
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    debugPrint('[QuillBotService] Initializing WebViewController...');

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
    // Use a mobile User Agent to mimic a real device and avoid connection refused errors
      ..setUserAgent('Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36')
      ..setNavigationDelegate(
        NavigationDelegate(
            onPageStarted: (url) {
              debugPrint('[QuillBotService] Page started loading: $url');
              _isPageLoaded = false;
            },
            onPageFinished: (url) {
              debugPrint('[QuillBotService] Page finished loading: $url');
              _isPageLoaded = true;
              // Optimize performance by stripping UI immediately
              _enableLightMode();
            },
            onWebResourceError: (error) {
              debugPrint('[QuillBotService] Web resource error: ${error.description}');
            },
            onNavigationRequest: (req) {
              if (req.url.contains('quillbot.com')) return NavigationDecision.navigate;
              return NavigationDecision.prevent;
            }
        ),
      )
      ..addJavaScriptChannel(
        'ApiListener',
        onMessageReceived: (JavaScriptMessage message) {
          // Ignore status updates, only capture final result or errors
          if (message.message.startsWith('STATUS:')) {
            debugPrint('[QuillBotService JS Log] ${message.message}');
            return;
          }

          if (_responseCompleter != null && !_responseCompleter!.isCompleted) {
            _responseCompleter!.complete(message.message);
            _responseCompleter = null;
          }
        },
      );

    // Start loading immediately upon instantiation
    _controller.loadRequest(Uri.parse('https://quillbot.com/ai-chat'));
    _isInitialized = true;
  }

  // Ensure this widget is mounted somewhere in the widget tree (e.g. Offstage)
  Widget get webView {
    if (!_isInitialized) initialize();
    return WebViewWidget(controller: _controller);
  }

  /// Replaces the heavy website UI with a lightweight placeholder.
  Future<void> _enableLightMode() async {
    const js = '''
      (function() {
        document.body.innerHTML = `
          <div style="display: flex; justify-content: center; align-items: center; height: 100vh; background: #f0f0f0;">
            <h1 style="color: #333;">⚡ QuillBot Service Active</h1>
          </div>
        `;
      })();
    ''';
    await _controller.runJavaScript(js);
  }

  void dispose() {
    if (!_isInitialized) return;
    debugPrint('[QuillBotService] Disposing service...');
    _controller.loadRequest(Uri.parse('about:blank'));
    _controller.clearCache();
  }

  /// NEW: Fetches a batch of 10 mixed tips/quotes/facts
  Future<List<String>> fetchHelpfulTips() async {
    if (!_isInitialized) initialize();

    // Wait for load
    int retries = 0;
    while (!_isPageLoaded) {
      await Future.delayed(const Duration(milliseconds: 500));
      retries++;
      if (retries > 20) return []; // Timeout
    }

    const prompt = '''
    Generate a mixed list of 10 items for a "Daily Inspiration" panel in an event app.
    
    Include a mix of:
    1. Short productivity tips (e.g. "Plan your day the night before").
    2. Motivational quotes from famous people (e.g. "Time is money. - Benjamin Franklin").
    3. Interesting facts about time, calendars, or social psychology.
    4. Specific tips for using the "Eventify" app (e.g. "Swipe right to delete events").
    
    Instructions:
    - Provide exactly 10 distinct items.
    - Keep each item SHORT (under 20 words).
    - Return ONLY a valid JSON array of strings. Example: ["Tip 1", "Quote 2"].
    - Do not include markdown formatting or extra conversational text.
    ''';

    try {
      final rawResponse = await _sendDirectApiRequest(prompt);
      final json = _cleanAndParseJson(rawResponse);

      if (json != null && json is List) {
        return json.map((e) => e.toString()).toList();
      } else if (json != null && json is Map && json.containsKey('tips')) {
        return (json['tips'] as List).map((e) => e.toString()).toList();
      }

      return [];
    } catch (e) {
      debugPrint("[QuillBotService] Tips Fetch Error: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>?> extractEventDetails(String caption) async {
    if (!_isInitialized) initialize();

    int retries = 0;
    while (!_isPageLoaded) {
      await Future.delayed(const Duration(milliseconds: 500));
      retries++;
      if (retries > 20) return null;
    }

    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(now);

    final prompt = '''
Analyze the following text and extract event details.
Current Date for context: $dateStr
Text: "$caption"

Instructions:
1. Generate a short, accurate title (4-5 words max).
2. Extract the Location, Date, and Starting Time.
3. Resolve relative dates like "tomorrow" based on the context date.
4. Pick a HEX background color (e.g. #FF5733) that matches the event's mood/theme.
5. Pick a HEX text color (e.g. #FFFFFF) that contrasts well with the background.
6. If any detail is not mentioned, strictly use "NA".
7. Return ONLY a valid JSON object.

Required JSON Structure:
{
  "title": "String",
  "location": "String",
  "date": "mmm d yyyy",
  "time": "hh:mm",
  "color": "#HEX",
  "textColor": "#HEX"
}
''';

    try {
      final rawResponse = await _sendDirectApiRequest(prompt);
      return _cleanAndParseJsonMap(rawResponse);
    } catch (e) {
      debugPrint("[QuillBotService] Extraction Error: $e");
      return null;
    }
  }

  /// Phase 1 addition: free-form chat with optional system context.
  /// Wraps the existing private `_sendDirectApiRequest` so callers don't
  /// need to know about the underlying JSON contract. Returns the assistant's
  /// raw text reply. Throws on network/parse failure (callers should catch).
  Future<String> chat(String userMessage, {String? systemContext}) async {
    if (!_isInitialized) initialize();
    final prompt = systemContext == null || systemContext.isEmpty
        ? userMessage
        : '$systemContext\n\n$userMessage';
    return _sendDirectApiRequest(prompt);
  }

  Future<String> _sendDirectApiRequest(String text) async {
    _responseCompleter = Completer<String>();
    final safeText = jsonEncode(text);

    final jsCode = '''
    (async function() {
        try {
            const inputMessage = $safeText;
            const payload = {
                "stream": true,
                "message": {
                    "role": "user",
                    "content": inputMessage,
                    "messageId": Math.random().toString(36).substring(2, 15),
                    "createdAt": new Date().toISOString(),
                    "files": []
                },
                "product": "ai-chat",
                "originUrl": "/ai-chat",
                "prompt": { "id": "ai_chat" },
                "tools": []
            };

            window.ApiListener.postMessage("STATUS: Sending Request...");

            const response = await fetch('https://quillbot.com/api/raven/quill-chat/responses', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json', 'Accept': '*/*' },
                body: JSON.stringify(payload)
            });

            if (!response.ok) {
                window.ApiListener.postMessage("Error: " + response.status);
                return;
            }

            const reader = response.body.getReader();
            const decoder = new TextDecoder();
            let fullText = '';

            while (true) {
                const { done, value } = await reader.read();
                if (done) break;
                
                fullText += decoder.decode(value, { stream: true });
                
                if (fullText.includes('"status":"DONE"')) {
                   const outputMarker = 'event: output_done';
                   const outputIndex = fullText.lastIndexOf(outputMarker);
                   
                   if (outputIndex !== -1) {
                       const dataMarker = 'data: ';
                       const dataIndex = fullText.indexOf(dataMarker, outputIndex);
                       
                       if (dataIndex !== -1) {
                           let endIndex = fullText.indexOf('\\n\\n', dataIndex);
                           if (endIndex === -1) endIndex = fullText.length;
                           
                           const jsonString = fullText.substring(dataIndex + dataMarker.length, endIndex).trim();
                           try {
                               const parsed = JSON.parse(jsonString);
                               if (parsed.text) {
                                   window.ApiListener.postMessage(parsed.text);
                                   return; 
                               }
                           } catch (e) { console.error("Parse error", e); }
                       }
                   }
                }
            }
            window.ApiListener.postMessage("Error: Stream ended without valid JSON");
        } catch (err) {
            window.ApiListener.postMessage("JS Error: " + err.toString());
        }
    })();
    ''';

    await _controller.runJavaScript(jsCode);
    return _responseCompleter!.future;
  }

  dynamic _cleanAndParseJson(String raw) {
    try {
      String clean = raw.trim();
      final RegExp jsonRegex = RegExp(r'(\[[\s\S]*\]|\{[\s\S]*\})');
      final match = jsonRegex.firstMatch(clean);

      if (match != null) {
        clean = match.group(0)!;
        return jsonDecode(clean);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic>? _cleanAndParseJsonMap(String raw) {
    final result = _cleanAndParseJson(raw);
    return (result is Map<String, dynamic>) ? result : null;
  }
}