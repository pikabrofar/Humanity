> **Not yet in effect.** These terms are pending review by a lawyer and contain
> placeholders in [BRACKETS]. The seller will finalize them before sales begin.

# Humanity Terms of Sale and End User License Agreement (version 2026-10-01)

---

## 1. Who and what

- These terms are between you and **[SELLER LEGAL NAME / DBA]**, an individual developer in Massachusetts, USA ("we"). They cover:
  - your purchase of a Humanity license key ("Key") through Gumroad;
  - your use of the official, pre-built Humanity, OculOS, ManOS and Murmur apps that we distribute ("Official Apps"); and
  - any support we provide.
- **Gumroad, Inc.** is the reseller and merchant of record for the payment. Gumroad's own terms govern the payment itself.

## 2. What the Key is, and how it relates to the open-source code

1. **Open source first.** Humanity's source code is published under the MIT License. **Nothing in these terms limits any right you have under the MIT License or under any third-party license listed in `THIRD_PARTY_NOTICES.md`.** You may build Humanity from source, without a Key, at no charge.
2. **What you pay for.** Your payment ($5 minimum, pay what you want) buys:
   - a Key that unlocks the Official Apps on your Macs;
   - the convenience of our builds;
   - updates we choose to release; and
   - best-effort support.
   It also funds development. It is not a fee for the source code.
3. **License to the Official Apps.** Subject to these terms, we grant you a non-exclusive, worldwide, non-transferable  license to activate and use the Official Apps with your Key on Macs that you own or control, for personal or business use. Each Key is for **[one person / up to N Macs]**.
4. **Key rules.** Keep your Key private. Do not publish, sell or share it, or use it to unlock copies for other people. We may deactivate Keys that are publicly posted or used in ways that clearly exceed §2.3.
5. **What is not restricted.** We do not restrict copying or redistributing the free DMG or the MIT source. Those are governed by the MIT License. You may not use our names or logos for builds you distribute (§15).

## 3. Open-source and third-party components

- The Official Apps include components from third parties under their own licenses, including:
  - FluidAudio (Apache-2.0);
  - fastcluster (BSD-2-Clause);
  - NVIDIA NeMo text-processing grammars (Apache-2.0); and
  - various Rust libraries (MIT/Apache-2.0).
- The apps also download speaker-diarization models from Hugging Face, licensed CC BY 4.0 by Fluid Inference, pyannote and BUT Speech@FIT.
- These licenses are listed in the app's About window and in `THIRD_PARTY_NOTICES.md`. **Where these terms conflict with an open-source license, the open-source license controls for that component.**
- Third-party licensors give you no warranty and have no obligations to you under these terms.

## 4. Privacy summary

- Camera and audio are processed on your Mac.
- The Official Apps contact the internet only to:
  - verify your Key with Gumroad (`api.gumroad.com`) at activation and about weekly;
  - download diarization models from Hugging Face the first time you process a meeting; and
  - send **text** (transcripts, never audio) to an AI provider **you** configure with your own API key.
- Details: `PRIVACY.md` [link].
- We do not receive your recordings, transcripts, voice profiles or gaze data.

## 5. Acceptable use: recording, voiceprints, surveillance

You are responsible for how you use the Official Apps. In particular:

1. **Get consent before recording.** Recording calls or conversations is illegal in many places without the consent of **everyone** taking part. This includes Massachusetts ([M.G.L. c. 272 §99](https://malegislature.gov/Laws/GeneralLaws/PartIV/TitleI/Chapter272/Section99)), California ([Penal Code §632](https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?sectionNum=632.&lawCode=PEN)) and about a dozen other U.S. states, plus many countries. Before you start a Meetings recording:
   - tell everyone you are recording; and
   - get their consent wherever the law requires it, including for participants located in other states or countries.
   Other participants' meeting apps will **not** show that you are recording.
2. **Voice profiles of other people.** A voice profile is a voiceprint, which is biometric data under laws such as Illinois BIPA ([740 ILCS 14](https://www.ilga.gov/Legislation/ILCS/Articles?ActID=3004&ChapterID=57)), Texas ([Bus. & Com. Code §503.001](https://statutes.capitol.texas.gov/Docs/BC/htm/BC.503.htm)), Washington ([RCW 19.375](https://app.leg.wa.gov/RCW/default.aspx?cite=19.375)) and the EU GDPR (Art. 9). Only save a voice profile of someone who has agreed to it. Where the law requires it, that agreement must be in writing. Delete profiles when you no longer need them.
3. **No surveillance.** Do not use the Official Apps to:
   - record, track or identify anyone covertly;
   - monitor employees, partners, family members or others without the notice and consent the law requires; or
   - capture another person's gaze, face or hand data without their knowledge.
4. **Sending transcripts to AI providers.** If you send transcripts to a cloud AI provider, you are sharing what other people said with that provider. Make sure you have the right to do so.
5. **No unlawful, harmful or high-risk use.** The Official Apps are not medical devices or certified assistive technology. Do not use them where an error could cause injury, financial loss or legal consequences without independent safeguards.
6. **Optional gaze model.** The OculOS `make cnn-model` script downloads third-party weights trained on the Gaze360 dataset. Those weights are licensed for **non-commercial research only**. Do not load them into the Official Apps for commercial use, and do not redistribute them.

## 6. Automation and accidental actions

- OculOS, ManOS and Murmur control your mouse and keyboard and can paste text into other apps.
- Gaze, gesture and speech recognition are imperfect. They can **click, drag, scroll, type or paste in the wrong place**. That can send messages, delete files, submit forms or trigger purchases you did not intend.
- Dictated text may be wrong, and clipboard contents may be replaced or restored.
- Keep backups.
- Use the pause controls and hotkeys.
- Do not leave pointer control active while you are away.
- Review AI-generated summaries and cleaned-up text before relying on them.

## 7. Third-party services

- **Gumroad.**
  - Gumroad processes your payment, issues your Key, and verifies it for us. Gumroad's [terms](https://gumroad.com/terms) and privacy policy apply to those steps.
  - If Gumroad is unavailable, activation and weekly re-checks may fail. The Official Apps keep working offline for **60 days** after the last successful check.
- **AI providers** (e.g. Groq, Google, OpenAI, Anthropic, OpenRouter, Mistral, DeepSeek, Together, xAI, Ollama).
  - Optional and off by default.
  - You use your own account and API key. You pay any provider charges, and the provider's terms and data practices apply.
  - We are not responsible for provider outputs, outages, pricing or data handling.
- **Hugging Face** hosts the diarization models.
- **Apple** provides the on-device speech, Vision and Apple Intelligence frameworks; Apple's terms apply.

## 8. Price and payment

- Pay what you want, with a $5 minimum, in the currency Gumroad shows.
- Gumroad collects and remits applicable sales tax and VAT as merchant of record.
- A Key is a one-time purchase. There is no subscription.

## 9. Refunds

1. You may request a refund within **[14 / 30] days** of purchase through Gumroad or by emailing **[CONTACT EMAIL]**. We grant first-time refund requests within that window without questions.
2. Gumroad has final say over refunds, chargebacks and disputes ([Gumroad Terms §7.1](https://gumroad.com/terms)). Gumroad does not return its fees on refunds; we absorb them.
3. **A refunded, charged-back or disputed Key stops working.** The Official Apps detect this at the next weekly check. You may still build Humanity from source.
4. **EU/EEA/UK consumers.** By activating your Key you ask us to supply digital content immediately, and you acknowledge that you lose your 14-day right of withdrawal once activation succeeds. This does not affect our voluntary refund window in §9.1 or your statutory rights if the Official Apps are faulty.

## 10. Updates, support and end of sale

- Updates are released at our discretion. They are free to Key holders for **[the life of the 1.x line / N years / as long as we sell Keys]**.
- There is no auto-updater. You choose when to install.
- Support is best-effort by email at **[CONTACT EMAIL]**.
- Features may change or be removed, including features that depend on third-party services.
- **If we stop selling Keys, or Gumroad's license verification stops working, we will release a version of the Official Apps that does not require a Key.**

## 11. Warranty disclaimer

- **To the fullest extent permitted by law, the Official Apps and Keys are provided "as is" and "as available", without warranties of any kind.** This includes implied warranties of merchantability, fitness for a particular purpose, title, non-infringement, accuracy of transcription, gaze, gesture or speaker identification, and uninterrupted or error-free operation.
- **This section does not limit any warranty or remedy that cannot be excluded under the law that applies to you. That includes, for Massachusetts consumers, M.G.L. c. 106 §2-316A. In jurisdictions that do not allow exclusion of implied warranties, those warranties are limited to the shortest period the law allows and to the remedy in §12.**

## 12. Limitation of liability

- **To the fullest extent permitted by law, we are not liable for indirect, incidental, special, consequential or punitive damages, or for lost data, profits or business.** This includes damages from:
  - unintended clicks, keystrokes or pastes;
  - recordings you make or fail to make;
  - transcription or summary errors; and
  - third-party services.
- **Our total liability for all claims relating to the Official Apps or your Key is limited to the greater of the amount you paid for your Key or US$[50].**
- **These limits do not apply to liability that cannot be limited by law, including liability for:**
  - death or personal injury caused by negligence;
  - fraud;
  - gross negligence or willful misconduct; and
  - claims under consumer-protection statutes that cannot be waived, including M.G.L. c. 93A.

## 13. Your responsibility for misuse (business users)

- If you use the Official Apps on behalf of a business or organization, you will indemnify us against third-party claims arising from:
  - your recordings, voice profiles or other monitoring of people; or
  - your breach of §5.

## 14. Termination

- These terms last until ended.
- We may deactivate a Key that was obtained fraudulently, refunded, charged back, or publicly shared, or that is used in material breach of §5. Where practical we will give notice and a chance to cure.
- You may stop using the Official Apps at any time.
- Termination does not affect your rights under the MIT License or other open-source licenses.
- §§3, 5, 11–13, 17–19 survive.

## 15. Intellectual property and trademarks

- We and our contributors keep all rights not expressly granted.
- The source code is licensed under MIT. **The names "Humanity", "OculOS", "ManOS" and "Murmur" and their icons are not licensed by MIT.**
- If you build or distribute your own copy, give it a different name and icon, and do not imply that it is official or endorsed by us. See `TRADEMARKS.md`.

## 16. Export and legal compliance

- You will not use or export the Official Apps in violation of U.S. export-control or sanctions laws.

## 17. Governing law

- These terms are governed by the laws of the **Commonwealth of Massachusetts, USA**, excluding its conflict-of-laws rules and the U.N. Convention on Contracts for the International Sale of Goods.
- **If you are a consumer, you keep the protection of mandatory laws of the place where you live.**

## 18. Disputes

1. **Talk to us first.** Email **[CONTACT EMAIL]** with a description of the problem. We will try to resolve it within 30 days. Most issues can be fixed with a refund or a new Key.
2. **Courts.** Unresolved disputes may be brought in the state or federal courts located in **[Suffolk / Middlesex] County, Massachusetts**. Consumers may instead sue in the courts where they live, where the law allows. **Either party may use small-claims court.**
3. **No mandatory arbitration.** [Option B in the reviewer note.]

## 19. General

- **Changes to these terms.** We may update these terms for future purchases and future versions. We will post the date and a summary of changes. Changes do not apply retroactively to a Key you already bought unless you accept them, for example by installing a new version that shows the new terms.
- **Entire agreement.** These terms are the entire agreement on the subjects they cover. They sit alongside the open-source licenses and Gumroad's terms.
- **Severability.** If a provision is unenforceable, it will be limited to the minimum extent necessary, and the rest remains in effect.
- **Assignment.** You may not assign these terms except as §2 allows. We may assign them to a successor that maintains the Official Apps.
- **No waiver.** Failure to enforce a provision is not a waiver.
- **Notices.** We send notices to the email on your Gumroad purchase. You send notices to **[CONTACT EMAIL]**.

## 20. Contact

**[SELLER LEGAL NAME / DBA]**, Massachusetts, USA, **[CONTACT EMAIL]**. Postal address for legal notices: **[ADDRESS OR REGISTERED-AGENT ADDRESS]**.

---

### Open questions for counsel (summary)
1. Is downloadable software "goods" under M.G.L. c. 106 for §2-316A? What warranty language is safe for MA consumers?
2. With Gumroad as merchant of record, who carries the EU consumer, CRA and PLD duties: Gumroad or the developer?
3. EU AI Act status of voice-profile speaker identification. Should voice profiles be disabled for EU buyers?
4. Should the seller form an LLC and buy E&O/cyber insurance before scaling sales?
5. Is a state-specific annex (NJ, MA, CA) worth it at this price point?
