"""Cloud Function to aggregate startup news from multiple sources."""

import os
import json
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Any
import functions_framework
from google.cloud import firestore
from google.cloud import storage
import google.generativeai as genai
import requests
from bs4 import BeautifulSoup
from urllib.parse import urljoin, urlparse

# Initialize logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize Firestore
db = firestore.client()

# Target websites for news aggregation
SOURCES = [
    {
        'name': 'SparkLabs Taiwan',
        'url': 'https://www.sparklabstaiwan.com',
        'selector': 'article, .post, [class*="news"]'
    },
    {
        'name': 'Startup 101',
        'url': 'https://startup101.biz/',
        'selector': 'article, .post, [class*="article"]'
    },
    {
        'name': '886 Studios',
        'url': 'https://886studios.com/resources',
        'selector': 'div[class*="resource"], article, .post'
    },
    {
        'name': '500 Global',
        'url': 'https://500.co/',
        'selector': 'article, .news, [class*="post"]'
    },
    {
        'name': 'AppWorks',
        'url': 'https://appworks.tw/',
        'selector': 'article, .post, [class*="news"]'
    }
]


class NewsAggregator:
    """Aggregates and processes news from multiple startup sources."""

    def __init__(self):
        self.gemini_api_key = os.environ.get('GEMINI_API_KEY')
        if self.gemini_api_key:
            genai.configure(api_key=self.gemini_api_key)
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Startup News Aggregator)'
        })

    def fetch_news(self, source: Dict[str, str]) -> List[Dict[str, Any]]:
        """Fetch news articles from a source website."""
        articles = []
        try:
            response = self.session.get(source['url'], timeout=10)
            response.raise_for_status()
            
            soup = BeautifulSoup(response.content, 'html.parser')
            elements = soup.select(source['selector'])
            
            for elem in elements[:5]:  # Limit to 5 per source
                title = elem.select_one('h1, h2, h3, .title')
                content = elem.select_one('p, .content, .description')
                link = elem.select_one('a')
                
                if title and content:
                    articles.append({
                        'source': source['name'],
                        'title': title.get_text(strip=True),
                        'content': content.get_text(strip=True),
                        'link': urljoin(source['url'], link['href']) if link else source['url'],
                        'fetched_at': datetime.utcnow().isoformat(),
                        'domain': urlparse(source['url']).netloc
                    })
        except Exception as e:
            logger.error(f"Error fetching from {source['name']}: {str(e)}")
        
        return articles

    def process_with_gemini(self, articles: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Use Gemini API to summarize and categorize articles."""
        if not self.gemini_api_key or not articles:
            return articles
        
        try:
            model = genai.GenerativeModel('gemini-1.5-pro')
            
            for article in articles:
                prompt = f"""
                Summarize and categorize the following startup news article in Traditional Chinese:
                
                Title: {article['title']}
                Content: {article['content']}
                
                Please provide:
                1. A brief summary (2-3 sentences)
                2. Category (e.g., Funding, Product Launch, Collaboration, Event)
                3. Key entities mentioned
                4. Relevance score (1-10)
                
                Format as JSON.
                """
                
                response = model.generate_content(prompt)
                
                try:
                    analysis = json.loads(response.text)
                    article.update({
                        'summary': analysis.get('summary', ''),
                        'category': analysis.get('category', 'Other'),
                        'entities': analysis.get('entities', []),
                        'relevance_score': analysis.get('relevance_score', 5),
                        'processed_at': datetime.utcnow().isoformat()
                    })
                except json.JSONDecodeError:
                    logger.warning(f"Could not parse Gemini response for {article['title']}")
        
        except Exception as e:
            logger.error(f"Error processing with Gemini: {str(e)}")
        
        return articles

    def store_articles(self, articles: List[Dict[str, Any]]) -> int:
        """Store articles in Firestore."""
        stored_count = 0
        
        for article in articles:
            try:
                # Create document ID from source + timestamp
                doc_id = f"{article['source'].lower().replace(' ', '_')}_{article['fetched_at']}"
                
                db.collection('articles').document(doc_id).set(article)
                stored_count += 1
                logger.info(f"Stored article: {article['title'][:50]}...")
            except Exception as e:
                logger.error(f"Error storing article: {str(e)}")
        
        return stored_count

    def run(self) -> Dict[str, Any]:
        """Execute the news aggregation pipeline."""
        all_articles = []
        
        # Fetch from all sources
        for source in SOURCES:
            logger.info(f"Fetching from {source['name']}...")
            articles = self.fetch_news(source)
            all_articles.extend(articles)
        
        logger.info(f"Total articles fetched: {len(all_articles)}")
        
        # Process with Gemini
        if self.gemini_api_key:
            all_articles = self.process_with_gemini(all_articles)
        
        # Store in Firestore
        stored = self.store_articles(all_articles)
        
        return {
            'status': 'success',
            'fetched_articles': len(all_articles),
            'stored_articles': stored,
            'timestamp': datetime.utcnow().isoformat()
        }


@functions_framework.http
def main(request):
    """HTTP Cloud Function to aggregate startup news."""
    try:
        aggregator = NewsAggregator()
        result = aggregator.run()
        return json.dumps(result)
    except Exception as e:        logger.error(f"Function error: {str(e)}")
return json.dumps({'status': 'error', 'message': str(e)})
