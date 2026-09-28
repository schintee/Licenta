const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const OpenAI = require("openai");

const OPENAI_API_KEY = defineSecret("OPENAI_API_KEY");

exports.askStockAssistant = onCall(
  {
    region: "europe-west1",
    timeoutSeconds: 60,
    memory: "256MiB",
    secrets: [OPENAI_API_KEY],
  },
  async (request) => {
    const data = request.data || {};

    const question =
      typeof data.question === "string" ? data.question.trim() : "";

    const warehouseContext =
      typeof data.warehouseContext === "string"
        ? data.warehouseContext.trim()
        : "";

    if (!question) {
      throw new HttpsError(
        "invalid-argument",
        "Întrebarea nu poate fi goală."
      );
    }

    if (!warehouseContext) {
      throw new HttpsError(
        "invalid-argument",
        "Contextul depozitului lipsește."
      );
    }

    if (question.length > 1200) {
      throw new HttpsError(
        "invalid-argument",
        "Întrebarea este prea lungă."
      );
    }

    const limitedContext = warehouseContext.slice(0, 24000);

    const openai = new OpenAI({
      apiKey: OPENAI_API_KEY.value(),
    });

    // Pentru costuri mici la licență.
    // Dacă vrei modelul cel mai puternic și ai acces, poți schimba în "gpt-5.5".
    const model = "gpt-5-mini";

    const systemPrompt = `
Ești AI Assistant pentru aplicația StockIQ, un sistem Flutter + Firebase + ESP32 pentru monitorizarea stocurilor.

Rolul tău:
- ajuți utilizatorul să înțeleagă stocurile, riscurile, comenzile, consumul și forecast-ul;
- răspunzi ca un copilot de depozit;
- oferi recomandări practice, clare și sigure.

Reguli obligatorii:
- Răspunde în limba română.
- Folosește doar contextul primit de la aplicația Flutter.
- Nu inventa produse, cutii, comenzi, cantități sau valori.
- Nu spune că ai acces direct la Firebase.
- Nu reciti date din Firebase; contextul este deja generat local de AiContextService.
- Nu muta logica AI Insights în backend.
- Nu expune detalii despre API key, Firebase Functions sau OpenAI.
- Dacă datele sunt insuficiente, spune clar ce lipsește.
- Pentru recomandări de comandă, menționează produsul, stocul actual, statusul și cantitatea sugerată dacă apare în context.
- Pentru risc, consum, forecast sau epuizare, explică pe baza valorilor existente în context.
- Răspunsurile trebuie să fie scurte, profesionale și ușor de folosit într-un depozit.
`;

    const userPrompt = `
Întrebarea utilizatorului:
${question}

Contextul depozitului StockIQ:
${limitedContext}
`;

    try {
      const response = await openai.responses.create({
        model,
        instructions: systemPrompt,
        input: userPrompt,
        max_output_tokens: 900,
        reasoning: {
          effort: "low",
        },
      });

      const answer = response.output_text?.trim();

      if (!answer) {
        throw new HttpsError(
          "internal",
          "OpenAI nu a returnat un răspuns text."
        );
      }

      return {
        answer,
        model,
      };
    } catch (error) {
      logger.error("askStockAssistant error", {
        message: error.message,
        status: error.status,
        code: error.code,
        type: error.type,
      });

      throw new HttpsError(
        "internal",
        "AI Assistant nu a putut genera un răspuns momentan."
      );
    }
  }
);