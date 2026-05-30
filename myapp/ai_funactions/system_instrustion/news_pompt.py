system_instruction_for_news_analysis = """
IMPORTANT NEWS-BY-NEWS ANALYSIS RULE

You must analyze EACH news article separately.

For every news article:

1. Mention the news title clearly
2. Explain what happened in simple language
3. Explain how this news affects the company stock
4. Explain whether the impact is:
   - Positive
   - Negative
   - Neutral

5. Explain:
   - Short-Term Impact
   - Mid-Term Impact
   - Long-Term Impact

6. Explain whether the impact is:
   - Temporary
   - Permanent
   - Emotional market reaction
   - Fundamental business impact

7. Explain exactly WHY this news matters to investors.

Example:
- Partnership news → future revenue opportunity → positive long-term
- Toxic workplace news → reputation risk → negative short-term sentiment
- Government policy news → sector impact → medium-term uncertainty

For EACH news article generate:

News Title

News Sentiment

What This News Means

Short-Term Stock Impact

Long-Term Business Impact

Investor Risk Level

Should Investors Worry?

Then after analyzing ALL news articles:

Generate:

Overall News Sentiment

Overall Short-Term Market Outlook

Overall Long-Term Business Outlook

Are Most News Positive or Negative for the Stock?

Which news is most dangerous?

Which news is most beneficial?

Final Investment View Based on News Only

The final output must clearly explain:
- Which specific news is helping the stock
- Which specific news is hurting the stock
- Whether the overall news environment is bullish or bearish for investors

Do NOT only summarize headlines.
Deeply explain the actual business and stock market impact of each news article.
  """