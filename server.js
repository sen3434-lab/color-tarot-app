require('dotenv').config();
const express = require('express');
const path = require('path');
const { resolveFamily, ...gemstones } = require('./data/gemstones');
const aromaTeaTable = require('./data/aroma_tea');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

// Public runtime config for the browser Supabase client.
// The anon key is designed to be public (row level security enforces access), so
// exposing it here is safe and mirrors how the existing reference app is built.
app.get('/api/config', (req, res) => {
  res.json({
    supabaseUrl: process.env.SUPABASE_URL,
    supabaseAnonKey: process.env.SUPABASE_ANON_KEY,
  });
});

// Generates a warm, personalized reading (color psychology + aroma/tea/gemstone
// prescriptions) from the user's mood text and the drawn card's DB content.
// The DB fields (love/wealth/health/career/etc.) are grounding context only —
// they are never shown to the user as a raw field dump, only woven into prose.
app.post('/api/reading', async (req, res) => {
  const { moodText, card } = req.body || {};
  if (!card || !card.name) {
    return res.status(400).json({ error: 'card is required' });
  }
  if (!process.env.GEMINI_API_KEY) {
    return res.status(503).json({ error: 'AI reading is not configured yet (missing GEMINI_API_KEY).' });
  }

  const family = resolveFamily(card.name);
  const gem = family ? gemstones[family] : null;
  // aroma_tea is keyed by the exact card name for the 21 tri-tone cards
  // (Light/Basic/Dark each have their own pairing) and by family name for
  // the 15 single-tone cards; family lookup is just a safety fallback.
  const aromaTea = aromaTeaTable[card.name] || (family ? aromaTeaTable[family] : null);

  // Light = mild, just-starting expression of the color; Dark = its most
  // intense/shadow expression (per the source data's `meaning` gradient).
  // Nudge the gemstone choice accordingly, unless the user's mood clearly
  // calls for the opposite.
  let toneHint = null;
  if (/^Light /.test(card.name)) {
    toneHint = '이 카드는 "Light" 단계 — 순하고 이제 막 피어나는 기운입니다. 내담자의 감정이 이를 반박하지 않는 한, "기운을 북돋는 원석"을 우선 고려하세요.';
  } else if (/^Dark /.test(card.name)) {
    toneHint = '이 카드는 "Dark" 단계 — 가장 강하고 그림자 쪽으로 기운 경고성 상태입니다. 내담자의 감정이 이를 반박하지 않는 한, "기운을 가라앉히는 원석"을 우선 고려하세요.';
  }

  const groundingLines = [
    `카드 이름: ${card.name}`,
    card.keyword && `키워드: ${card.keyword}`,
    card.meaning && `카드 의미: ${card.meaning}`,
    card.love && `사랑 관련: ${card.love}`,
    card.wealth && `재물 관련: ${card.wealth}`,
    card.health && `건강 관련: ${card.health}`,
    card.career && `일/진로 관련: ${card.career}`,
    card.caution && `유의할 점: ${card.caution}`,
    card.advice && `조언: ${card.advice}`,
    gem && `이 색의 원석 개운법 — 기운을 북돋을 때: ${gem.boost.name}(${gem.boost.en}) · ${gem.boost.desc}`,
    gem && `기운을 가라앉힐 때: ${gem.calm.name}(${gem.calm.en}) · ${gem.calm.desc}`,
    toneHint,
    aromaTea && `이 색의 지정 아로마: ${aromaTea.aroma.name}(${aromaTea.aroma.en})`,
    aromaTea && `이 색의 지정 티: ${aromaTea.tea.name}(${aromaTea.tea.en})`,
  ].filter(Boolean).join('\n');

  // Aroma/tea/gemstone *names* are fixed per color family (authored data,
  // not left to the model) so the same color always prescribes the same
  // substance — only the reasoning text is generated, personalized to the
  // user's mood.
  const systemPrompt = `당신은 '오즈마 컬러 타로'에서 사용자의 마음을 보살펴주는 따뜻한 멘토입니다. 오랫동안 곁에서 지켜봐 온 사람처럼, 다정하고 자상한 말투로 사용자가 지금 느끼는 감정과 뽑힌 컬러 카드의 심리 데이터를 참고하여 힐링이 되는 한국어 리딩을 작성합니다.

규칙:
- 아래로 전달되는 카드 데이터는 참고 자료일 뿐입니다. "사랑:", "재물:" 같은 항목명이나 카드의 키워드 목록을 절대 그대로 나열하지 말고, 그 의미를 자연스러운 이야기 속에 녹여내세요.
- 사용자의 질문/감정에 먼저 진심으로 공감하고 다독여주세요. 그 다음 카드의 색이 지금 이 순간 어떤 의미로 다가오는지, 다정한 멘토가 조곤조곤 이야기해주듯 풀어주세요.
- 분석하거나 진단하듯 말하지 말고, 옆에서 마음을 어루만져주는 느낌으로 씁니다. "~하시군요", "~일 거예요", "괜찮아요" 같은 부드럽고 보살피는 어투를 사용하세요.
- 아로마와 티는 위에 주어진 "이 색의 지정 아로마/티"를 그대로 사용해서, 왜 지금 이 사람에게 이 향과 차가 어울리는지만 다정하게 설명하세요. 다른 향/차로 바꾸지 마세요.
- 원석은 위에 주어진 두 원석(기운을 북돋는 것/가라앉히는 것) 중 사용자의 현재 감정 상태에 더 어울리는 하나를 골라 그 이름 그대로 사용하고, 왜 그것을 골랐는지 설명하세요.
- 전체 톤은 절대 판단하거나 지시하지 않고, 처음부터 끝까지 희망적이고 다정하며 꼭 안아주는 듯한 위로가 되도록 씁니다.
- 반드시 아래 JSON 형식으로만 답하세요. 다른 텍스트를 덧붙이지 마세요.

{
  "reading": "카드 해석 — 사용자의 감정에 공감하며 시작해, 컬러의 의미를 자연스러운 이야기로 풀어낸 3~5문장",
  "aromaReason": "지정된 아로마가 왜 지금 이 사람에게 어울리는지, 2~3문장",
  "teaReason": "지정된 티가 왜 지금 이 사람에게 어울리는지, 2~3문장",
  "gemstoneChoice": "boost 또는 calm 중 하나",
  "gemstoneReason": "고른 원석이 왜 지금 이 사람에게 어울리는지, 2~3문장",
  "closing": "희망을 주는 따뜻한 마무리 메시지, 1~2문장"
}`;

  const userPrompt = `사용자가 지금 느끼는 감정/질문: "${moodText || '(별도로 남긴 말은 없어요)'}"

뽑힌 카드 정보:
${groundingLines}`;

  const model = process.env.GEMINI_MODEL || 'gemini-2.5-flash';

  try {
    const apiRes = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${process.env.GEMINI_API_KEY}`,
      {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: systemPrompt }] },
          contents: [{ role: 'user', parts: [{ text: userPrompt }] }],
          generationConfig: {
            responseMimeType: 'application/json',
            maxOutputTokens: 2048,
            thinkingConfig: { thinkingBudget: 0 },
          },
        }),
      }
    );

    if (!apiRes.ok) {
      const errText = await apiRes.text();
      console.error('Gemini API error', apiRes.status, errText);
      return res.status(502).json({ error: 'AI reading failed' });
    }

    const data = await apiRes.json();
    const text = data.candidates?.[0]?.content?.parts?.[0]?.text || '';
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      console.error('Could not find JSON in AI response', text);
      return res.status(502).json({ error: 'AI reading failed' });
    }
    const parsed = JSON.parse(jsonMatch[0]);

    const gemChoice = parsed.gemstoneChoice === 'calm' ? 'calm' : 'boost';
    const chosenGem = gem ? gem[gemChoice] : null;

    res.json({
      reading: parsed.reading,
      aroma: {
        name: aromaTea ? `${aromaTea.aroma.name} (${aromaTea.aroma.en})` : null,
        reason: parsed.aromaReason,
      },
      tea: {
        name: aromaTea ? `${aromaTea.tea.name} (${aromaTea.tea.en})` : null,
        reason: parsed.teaReason,
      },
      gemstone: {
        name: chosenGem ? `${chosenGem.name} (${chosenGem.en})` : null,
        reason: parsed.gemstoneReason,
      },
      closing: parsed.closing,
    });
  } catch (err) {
    console.error('AI reading error', err);
    res.status(502).json({ error: 'AI reading failed' });
  }
});

app.use(express.static(path.join(__dirname, 'public')));

app.listen(PORT, () => {
  console.log(`Color Tarot Healing App running at http://localhost:${PORT}`);
});
