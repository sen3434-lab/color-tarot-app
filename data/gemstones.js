// Ported from education/color-tarot/_07-appendix-gemstones.html (오즈마 원석 개운법).
// Keyed by the English color-family name used in tarot_cards.name (e.g. "Light Red" -> "Red").
// Order matters for matching: longer/more specific names ("Old Copper") must be checked
// before shorter ones ("Copper") when resolving a card name to a family.
module.exports = {
  Red: { desc: 'Red는 강한 행동력과 열정, 카리스마를 상징하는 색으로 몸의 근원적인 생명 에너지와 맞닿아 있습니다.', boost: { name: '가넷', en: 'Garnet', desc: '뿌리 차크라와 연결되어 지친 열정과 추진력을 다시 타오르게 하는 원석입니다.' }, calm: { name: '로즈쿼츠', en: 'Rose Quartz', desc: '부드러운 사랑의 진동으로 격해진 감정과 다툼의 기운을 가라앉혀 줍니다.' } },
  Orange: { desc: 'Orange는 즐거움과 물질적 풍요, 미식과 쾌락을 상징하는 색입니다.', boost: { name: '카넬리안', en: 'Carnelian', desc: '활력과 실행력을 높여주어 즐거움을 현실적인 성취로 이어주는 원석입니다.' }, calm: { name: '블루레이스 아게이트', en: 'Blue Lace Agate', desc: '과도한 욕구와 충동적인 소비를 차분하게 다스려줍니다.' } },
  Yellow: { desc: 'Yellow는 지혜와 판단력, 현실적인 계산 능력을 상징하는 색입니다.', boost: { name: '시트린', en: 'Citrine', desc: '명료한 사고와 자신감, 재물운을 함께 끌어올려 주는 대표적인 원석입니다.' }, calm: { name: '자수정', en: 'Amethyst', desc: '지나치게 계산적으로 굳어진 마음을 이완시키고 직관을 열어줍니다.' } },
  Green: { desc: 'Green은 안정적인 성장과 조화, 원리원칙을 상징하는 색입니다.', boost: { name: '그린 아벤츄린', en: 'Green Aventurine', desc: '행운과 기회를 끌어당기며 정체된 성장에 다시 흐름을 만들어 줍니다.' }, calm: { name: '카넬리안', en: 'Carnelian', desc: '굳어진 고집과 정체된 에너지에 유연한 활력을 불어넣어 줍니다.' } },
  Blue: { desc: 'Blue는 자유로움과 상상력, 그에 따르는 책임감을 상징하는 색입니다.', boost: { name: '아쿠아마린', en: 'Aquamarine', desc: '막힘없는 소통과 평온한 자유의 기운을 북돋아 주는 원석입니다.' }, calm: { name: '타이거아이', en: "Tiger's Eye", desc: '과도한 방임과 흐트러진 지출·생활 습관을 현실감 있게 붙잡아 줍니다.' } },
  Indigo: { desc: 'Indigo는 깊은 통찰과 인내, 정신적인 성숙을 상징하는 색입니다.', boost: { name: '라피스라줄리', en: 'Lapis Lazuli', desc: '내면의 지혜와 직관을 깨워 통찰력을 한층 깊게 해주는 원석입니다.' }, calm: { name: '문스톤', en: 'Moonstone', desc: '오래 쌓인 마음고생과 긴장을 부드럽게 풀어주고 정서를 안정시켜 줍니다.' } },
  Violet: { desc: 'Violet은 예술적 감수성과 치유, 정신적 고양을 상징하는 색입니다.', boost: { name: '자수정', en: 'Amethyst', desc: '영적인 감수성과 치유의 기운을 높여주는 바이올렛 계열의 대표 원석입니다.' }, calm: { name: '시트린', en: 'Citrine', desc: '가라앉은 기분과 불안한 마음에 따뜻한 활력과 현실감을 더해줍니다.' } },
  Sky: { desc: 'Sky는 진실과 자유, 순수한 믿음을 상징하는 색입니다.', boost: { name: '아쿠아마린', en: 'Aquamarine', desc: '맑고 진실된 기운을 더해 관계 속 믿음과 소통을 도와줍니다.' }, calm: { name: '카넬리안', en: 'Carnelian', desc: '지나치게 나른하고 무기력해진 상태에 활력을 채워줍니다.' } },
  Pink: { desc: 'Pink는 매력과 사랑, 섬세한 감정의 시작을 상징하는 색입니다.', boost: { name: '로즈쿼츠', en: 'Rose Quartz', desc: '사랑과 호감의 기운을 부드럽게 끌어올려 주는 대표적인 원석입니다.' }, calm: { name: '스모키쿼츠', en: 'Smoky Quartz', desc: '감정에 쉽게 휩쓸릴 때 현실적인 판단력을 잡아줍니다.' } },
  White: { desc: 'White는 순수함과 완벽함, 새로운 시작을 상징하는 색입니다.', boost: { name: '클리어쿼츠', en: 'Clear Quartz', desc: '모든 에너지를 정화하고 증폭시켜 새 출발의 기운을 밝혀줍니다.' }, calm: { name: '카넬리안', en: 'Carnelian', desc: '비어있는 듯한 무기력감에 따뜻한 활력을 채워줍니다.' } },
  Gray: { desc: 'Gray는 불투명함과 은폐, 명확하지 않은 상황을 상징하는 색입니다.', boost: { name: '스모키쿼츠', en: 'Smoky Quartz', desc: '신중하게 상황을 지켜보며 스스로를 보호하는 힘을 더해줍니다.' }, calm: { name: '시트린', en: 'Citrine', desc: '답답하고 안개 낀 듯한 기운을 걷어내고 명료함을 되찾아줍니다.' } },
  Black: { desc: 'Black은 멈춤과 흡수, 휴식과 재탄생을 상징하는 색입니다.', boost: { name: '블랙 옵시디언', en: 'Black Obsidian', desc: '부정적인 기운을 강하게 흡수·차단하며 확실한 멈춤을 만들어줍니다.' }, calm: { name: '카넬리안', en: 'Carnelian', desc: '멈춰버린 에너지에 다시 온기와 활력을 불어넣어 재시작을 돕습니다.' } },
  Rainbow: { desc: 'Rainbow는 약속과 화합, 관계의 회복을 상징하는 색입니다.', boost: { name: '레인보우 형석', en: 'Rainbow Fluorite', desc: '여러 기운을 조화롭게 통합하며 화해와 안정을 돕는 원석입니다.' }, calm: { name: '스모키쿼츠', en: 'Smoky Quartz', desc: '지나치게 낙관적인 기대를 현실적으로 다잡아줍니다.' } },
  Various: { desc: 'Various는 다양함과 호기심, 분산된 에너지를 상징하는 색입니다.', boost: { name: '아게이트', en: 'Agate', desc: '여러 재능과 관심사를 조화롭게 엮어 다재다능함을 키워줍니다.' }, calm: { name: '헤마타이트', en: 'Hematite', desc: '산만하게 흩어진 에너지를 한곳으로 모아 집중력을 높여줍니다.' } },
  Ocher: { desc: 'Ocher는 원리원칙과 실용, 안정적인 신뢰를 상징하는 색입니다.', boost: { name: '타이거아이', en: "Tiger's Eye", desc: '현실적인 판단력과 끈기 있는 실행력을 더해주는 원석입니다.' }, calm: { name: '아쿠아마린', en: 'Aquamarine', desc: '지나치게 고집스러워진 마음에 유연함을 더해줍니다.' } },
  'Old Copper': { desc: 'Old Copper는 전통과 인내, 뒤늦게 찾아오는 결실을 상징하는 색입니다.', boost: { name: '스모키쿼츠', en: 'Smoky Quartz', desc: '묵묵히 버텨내는 힘과 안정감을 더해주는 원석입니다.' }, calm: { name: '카넬리안', en: 'Carnelian', desc: '너무 오래 정체된 상황에 다시 움직이는 활력을 불어넣어 줍니다.' } },
  Copper: { desc: 'Copper는 연결과 순환, 활발한 교류 에너지를 상징하는 색입니다.', boost: { name: '카넬리안', en: 'Carnelian', desc: '활발한 순환과 거래의 에너지를 북돋아 주는 원석입니다.' }, calm: { name: '아쿠아마린', en: 'Aquamarine', desc: '지나치게 빠른 흐름과 소모적인 교류에 차분함을 더해줍니다.' } },
  Turquoise: { desc: 'Turquoise는 행운과 결혼, 가까운 인연을 상징하는 색입니다.', boost: { name: '터콰이즈', en: 'Turquoise', desc: '가까운 사람을 통한 행운과 좋은 인연의 기운을 강하게 끌어당겨 줍니다.' }, calm: { name: '스모키쿼츠', en: 'Smoky Quartz', desc: '성급하게 인연에 기대는 마음을 차분하게 다잡아줍니다.' } },
  Vintage: { desc: 'Vintage는 성숙함과 희소성, 오래된 인연의 재회를 상징하는 색입니다.', boost: { name: '가넷', en: 'Garnet', desc: '오래 묵은 인연과 경험에 깊이와 의미를 더해주는 원석입니다.' }, calm: { name: '클리어쿼츠', en: 'Clear Quartz', desc: '과거에 지나치게 머무르지 않도록 새로운 시각을 열어줍니다.' } },
  Translucence: { desc: 'Translucence는 보이지 않는 연결과 신호, 네트워크를 상징하는 색입니다.', boost: { name: '아쿠아마린', en: 'Aquamarine', desc: '섬세한 소통과 연결의 신호를 더 예민하게 받아들이도록 도와줍니다.' }, calm: { name: '헤마타이트', en: 'Hematite', desc: '너무 많은 연결과 정보에 지쳤을 때 안정적으로 그라운딩해줍니다.' } },
  Gold: { desc: 'Gold는 성공과 풍요, 완성을 상징하는 색입니다.', boost: { name: '타이거아이', en: "Tiger's Eye", desc: '목표를 향한 자신감과 결단력을 더욱 강하게 끌어올려 주는 원석입니다.' }, calm: { name: '자수정', en: 'Amethyst', desc: '성공에 대한 압박감과 긴장을 이완시켜 줍니다.' } },
  Silver: { desc: 'Silver는 가족과 전통, 그리움을 상징하는 색입니다.', boost: { name: '문스톤', en: 'Moonstone', desc: '가족과 소중한 사람들에 대한 정서적 유대와 그리움의 감성을 부드럽게 채워줍니다.' }, calm: { name: '시트린', en: 'Citrine', desc: '그리움에 오래 머무르기보다 지금 이 순간에 집중하도록 도와줍니다.' } },
};

// Ordered longest-name-first so "Old Copper" matches before "Copper", etc.
module.exports._orderedKeys = Object.keys(module.exports).sort((a, b) => b.length - a.length);

module.exports.resolveFamily = function resolveFamily(cardName) {
  if (!cardName) return null;
  const name = cardName.toLowerCase();
  for (const key of module.exports._orderedKeys) {
    if (name.includes(key.toLowerCase())) return key;
  }
  return null;
};
