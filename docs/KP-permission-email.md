# Draft: permission / attribution request to Kaiser Permanente

To: PerinatalResearchUnit@kp.org
Subject: INQUIRING NEONATAL SEPSIS – independent iOS implementation of the EOS calculator

---

Dear Perinatal Research Unit,

I am a [role] at [institution]. I am developing an iOS application that implements the
neonatal early-onset sepsis risk model described in Puopolo et al. (2011), Escobar et al.
(2014), Kuzniewicz et al. (2017) and Kuzniewicz et al. (2024), using the coefficients,
likelihood ratios, intercept-adjustment formula and recommendation thresholds published on
your calculator website's EMR Implementation and 2024 Model Update FAQ pages.

Your General FAQ states that "the calculator is open source. Please attribute appropriately,"
and that no iPhone app has been developed by the calculator's authors. Before going further
I would like to confirm the following with you:

1. That an independent, non-commercial [or: commercial] iOS implementation of the published
   model is acceptable to Kaiser Permanente.
2. How you would like the model and the calculator attributed in the app and on its App Store
   listing. My current wording is: "Independent implementation of the published Kaiser
   Permanente neonatal early-onset sepsis risk model (Kuzniewicz et al., 2017, 2024). Not
   affiliated with or endorsed by Kaiser Permanente." I will not use the Kaiser Permanente
   name or marks in the app's name, icon or branding.
3. Two technical points where your published materials are ambiguous:
   a. For the updated (2024) model at 0.3/1000 incidence, does the web calculator use the
      intercept 57.3 (the fit at the KPNC rate of 0.2763/1000) or 57.4 from the published
      adjustment formula?
   b. For the original (2017) model, intercepts are published for 0.3–0.6/1000. Could you share
      the intercepts used for the other incidence options (0.1, 0.2, 0.7–0.9, 1, 2, 4/1000),
      or confirm that they follow the same adjustment formula?
4. Whether the clinical recommendation thresholds (composite risk ≥ 1 → blood culture,
   ≥ 3 → empiric antibiotics; risk at birth ≥ 1 → vitals every 4 h for 24 h) are unchanged
   for the 2024 model.

The app will state that it is intended for clinicians trained and experienced in the care of
newborn infants, will present both the original and updated models, and will store no patient
data. I would be glad to share a test build with you.

Thank you for making the model and its implementation details publicly available.

Kind regards,

[Name]
[Title, institution]
[Email]
