// Fixed aroma & tea correspondence per card.
//
// For the 7 tri-tone hue families (Red/Orange/Yellow/Green/Blue/Indigo/Violet),
// each of the 21 individual cards has its OWN entry, because in the source
// data (tarot_cards) only the `meaning` field differs across Light/Basic/Dark
// — it's an intensity gradient (Light = mild, just-starting expression;
// Basic = standard, full expression; Dark = extreme/shadow expression), and
// love/wealth/health/career text is shared across all three. So Light gets a
// brighter, uplifting pairing; Dark gets a calming, grounding one; Basic
// keeps the hue's core identity pairing.
//
// The 15 single-tone extended colors (no Light/Dark variant exists) keep one
// entry each, same as before.
module.exports = {
  'Light Red': { aroma: { name: '자몽', en: 'Grapefruit' }, tea: { name: '히비스커스차', en: 'Hibiscus Tea' } },
  'Red': { aroma: { name: '로즈마리', en: 'Rosemary' }, tea: { name: '히비스커스차', en: 'Hibiscus Tea' } },
  'Dark Red': { aroma: { name: '클라리세이지', en: 'Clary Sage' }, tea: { name: '캐모마일차', en: 'Chamomile Tea' } },

  'Light Orange': { aroma: { name: '만다린', en: 'Mandarin' }, tea: { name: '루이보스차', en: 'Rooibos Tea' } },
  'Orange': { aroma: { name: '스위트오렌지', en: 'Sweet Orange' }, tea: { name: '루이보스차', en: 'Rooibos Tea' } },
  'Dark Orange': { aroma: { name: '베르가못', en: 'Bergamot' }, tea: { name: '페퍼민트차', en: 'Peppermint Tea' } },

  'Light Yellow': { aroma: { name: '자몽', en: 'Grapefruit' }, tea: { name: '레몬밤차', en: 'Lemon Balm Tea' } },
  'Yellow': { aroma: { name: '레몬', en: 'Lemon' }, tea: { name: '페퍼민트차', en: 'Peppermint Tea' } },
  'Dark Yellow': { aroma: { name: '라벤더', en: 'Lavender' }, tea: { name: '캐모마일차', en: 'Chamomile Tea' } },

  'Light Green': { aroma: { name: '페퍼민트', en: 'Peppermint' }, tea: { name: '녹차', en: 'Green Tea' } },
  'Green': { aroma: { name: '유칼립투스', en: 'Eucalyptus' }, tea: { name: '녹차', en: 'Green Tea' } },
  'Dark Green': { aroma: { name: '시더우드', en: 'Cedarwood' }, tea: { name: '캐모마일차', en: 'Chamomile Tea' } },

  'Light Blue': { aroma: { name: '페퍼민트', en: 'Peppermint' }, tea: { name: '블루멜로우차', en: 'Blue Mallow Tea' } },
  'Blue': { aroma: { name: '라벤더', en: 'Lavender' }, tea: { name: '블루멜로우차', en: 'Blue Mallow Tea' } },
  'Dark Blue': { aroma: { name: '베티버', en: 'Vetiver' }, tea: { name: '우롱차', en: 'Oolong Tea' } },

  'Light Indigo': { aroma: { name: '로즈마리', en: 'Rosemary' }, tea: { name: '자스민차', en: 'Jasmine Tea' } },
  'Indigo': { aroma: { name: '프랑킨센스', en: 'Frankincense' }, tea: { name: '자스민차', en: 'Jasmine Tea' } },
  'Dark Indigo': { aroma: { name: '라벤더', en: 'Lavender' }, tea: { name: '캐모마일차', en: 'Chamomile Tea' } },

  'Light Violet': { aroma: { name: '제라늄', en: 'Geranium' }, tea: { name: '라벤더차', en: 'Lavender Tea' } },
  'Violet': { aroma: { name: '클라리세이지', en: 'Clary Sage' }, tea: { name: '라벤더차', en: 'Lavender Tea' } },
  'Dark Violet': { aroma: { name: '프랑킨센스', en: 'Frankincense' }, tea: { name: '캐모마일차', en: 'Chamomile Tea' } },

  // Single-tone extended colors — unchanged.
  Sky: { aroma: { name: '페퍼민트', en: 'Peppermint' }, tea: { name: '캐모마일차', en: 'Chamomile Tea' } },
  Pink: { aroma: { name: '제라늄', en: 'Geranium' }, tea: { name: '로즈차', en: 'Rose Tea' } },
  White: { aroma: { name: '네롤리', en: 'Neroli' }, tea: { name: '백차', en: 'White Tea' } },
  Gray: { aroma: { name: '시더우드', en: 'Cedarwood' }, tea: { name: '우롱차', en: 'Oolong Tea' } },
  Black: { aroma: { name: '파촐리', en: 'Patchouli' }, tea: { name: '보이차', en: 'Pu-erh Tea' } },
  Rainbow: { aroma: { name: '일랑일랑', en: 'Ylang Ylang' }, tea: { name: '캐모마일 블렌드', en: 'Chamomile Blend' } },
  Various: { aroma: { name: '베르가못', en: 'Bergamot' }, tea: { name: '얼그레이', en: 'Earl Grey' } },
  Ocher: { aroma: { name: '베티버', en: 'Vetiver' }, tea: { name: '보리차', en: 'Barley Tea' } },
  'Old Copper': { aroma: { name: '샌달우드', en: 'Sandalwood' }, tea: { name: '대추차', en: 'Jujube Tea' } },
  Copper: { aroma: { name: '진저', en: 'Ginger' }, tea: { name: '생강차', en: 'Ginger Tea' } },
  Turquoise: { aroma: { name: '네롤리', en: 'Neroli' }, tea: { name: '히비스커스 로즈 블렌드', en: 'Hibiscus Rose Blend' } },
  Vintage: { aroma: { name: '샌달우드 & 파촐리', en: 'Sandalwood & Patchouli' }, tea: { name: '다즐링 홍차', en: 'Darjeeling Black Tea' } },
  Translucence: { aroma: { name: '티트리', en: 'Tea Tree' }, tea: { name: '그린 루이보스차', en: 'Green Rooibos Tea' } },
  Gold: { aroma: { name: '프랑킨센스 & 오렌지', en: 'Frankincense & Orange' }, tea: { name: '캐모마일 허니 블렌드', en: 'Chamomile Honey Blend' } },
  Silver: { aroma: { name: '라벤더 & 샌달우드', en: 'Lavender & Sandalwood' }, tea: { name: '루이보스 밀크티', en: 'Rooibos Milk Tea' } },
};
