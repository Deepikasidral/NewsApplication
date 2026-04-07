"""
Intelligent company symbol mapping from CSV file with advanced AI-powered matching
"""
import pandas as pd
import os
import re
from typing import Dict, Optional, List, Tuple
from difflib import SequenceMatcher
from collections import defaultdict

# Load companies from CSV
CSV_PATH = os.path.join(os.path.dirname(__file__), 'New_Company_Data1.csv')

class CompanyMatcher:
    """Advanced company name matching with fuzzy logic and AI-like intelligence"""
    
    def __init__(self):
        self.company_to_symbol = {}
        self.symbol_to_name = {}
        self.symbol_to_company = {}
        self.normalized_names = {}
        self.keywords_index = defaultdict(list)
        self.load_data()
        self._build_search_index()
    
    def load_data(self):
        """Load and process company data from CSV"""
        try:
            df = pd.read_csv(CSV_PATH)
            
            for _, row in df.iterrows():
                # Handle different CSV column formats
                if 'NAME OF COMPANY' in df.columns:
                    company_name = str(row['NAME OF COMPANY']).strip()
                    symbol = str(row['SYMBOL']).strip().upper()
                elif 'company_name' in df.columns:
                    company_name = str(row['company_name']).strip()
                    symbol = str(row['symbol']).strip().upper()
                else:
                    # Try to detect columns automatically
                    cols = df.columns.tolist()
                    company_name = str(row[cols[1]]).strip()  # Usually second column
                    symbol = str(row[cols[0]]).strip().upper()  # Usually first column
                
                if company_name and symbol and company_name != 'nan' and symbol != 'NAN':
                    # Store mappings
                    company_lower = company_name.lower()
                    self.company_to_symbol[company_lower] = symbol
                    self.symbol_to_name[symbol] = company_name
                    self.symbol_to_company[symbol] = company_name
                    
                    # Store normalized version for better matching
                    normalized = self._normalize_company_name(company_name)
                    self.normalized_names[normalized] = symbol
                    
        except Exception as e:
            print(f"Error loading companies CSV: {e}")
    
    def _normalize_company_name(self, name: str) -> str:
        """Normalize company name for better matching"""
        # Convert to lowercase
        name = name.lower()
        
        # Remove common suffixes and prefixes
        suffixes = ['limited', 'ltd', 'inc', 'corp', 'corporation', 'company', 'co', 
                   'pvt', 'private', 'public', 'plc', 'llc', 'llp', 'industries', 
                   'enterprises', 'group', 'holdings', 'international', 'india']
        
        for suffix in suffixes:
            name = re.sub(rf'\b{suffix}\b', '', name)
        
        # Remove special characters and extra spaces
        name = re.sub(r'[^a-zA-Z0-9\s]', ' ', name)
        name = re.sub(r'\s+', ' ', name).strip()
        
        return name
    
    def _build_search_index(self):
        """Build keyword index for fast searching"""
        for company_name, symbol in self.company_to_symbol.items():
            # Split into keywords
            words = self._normalize_company_name(company_name).split()
            for word in words:
                if len(word) > 2:  # Ignore very short words
                    self.keywords_index[word].append((symbol, company_name))
    
    def _calculate_similarity(self, str1: str, str2: str) -> float:
        """Calculate similarity between two strings"""
        return SequenceMatcher(None, str1.lower(), str2.lower()).ratio()
    
    def _fuzzy_match(self, query: str, threshold: float = 0.6) -> List[Tuple[str, str, float]]:
        """Perform fuzzy matching against all company names"""
        matches = []
        query_normalized = self._normalize_company_name(query)
        
        # Check normalized names first
        for normalized_name, symbol in self.normalized_names.items():
            similarity = self._calculate_similarity(query_normalized, normalized_name)
            if similarity >= threshold:
                company_name = self.symbol_to_company[symbol]
                matches.append((symbol, company_name, similarity))
        
        # Check original names
        for company_name, symbol in self.company_to_symbol.items():
            similarity = self._calculate_similarity(query.lower(), company_name)
            if similarity >= threshold:
                matches.append((symbol, self.symbol_to_name[symbol], similarity))
        
        # Sort by similarity score (descending)
        matches.sort(key=lambda x: x[2], reverse=True)
        
        # Remove duplicates while preserving order
        seen = set()
        unique_matches = []
        for match in matches:
            if match[0] not in seen:
                seen.add(match[0])
                unique_matches.append(match)
        
        return unique_matches[:10]  # Return top 10 matches
    
    def _keyword_search(self, query: str) -> List[Tuple[str, str, float]]:
        """Search using keyword matching"""
        query_words = self._normalize_company_name(query).split()
        matches = defaultdict(float)
        
        for word in query_words:
            if word in self.keywords_index:
                for symbol, company_name in self.keywords_index[word]:
                    matches[symbol] += 1.0 / len(query_words)
        
        # Convert to list and sort
        result = [(symbol, self.symbol_to_name[symbol], score) 
                 for symbol, score in matches.items()]
        result.sort(key=lambda x: x[2], reverse=True)
        
        return result[:10]
    
    def get_best_symbol(self, company_name: str) -> str:
        """Get the best stock symbol for a company name using AI-like matching"""
        if not company_name or company_name.strip() == '':
            return ''
        
        company_name = company_name.strip()
        company_lower = company_name.lower()
        
        # Common company mappings (fallback for popular stocks)
        common_mappings = {
            'apple': 'AAPL',
            'microsoft': 'MSFT', 
            'google': 'GOOGL',
            'amazon': 'AMZN',
            'tesla': 'TSLA',
            'sbi': 'SBIN',
            'state bank': 'SBIN',
            'state bank of india': 'SBIN',
            'hdfc bank': 'HDFCBANK',
            'icici bank': 'ICICIBANK',
            'axis bank': 'AXISBANK',
            'kotak bank': 'KOTAKBANK',
            'reliance': 'RELIANCE',
            'tcs': 'TCS',
            'tata consultancy': 'TCS',
            'infosys': 'INFY',
            'wipro': 'WIPRO',
            'hcl tech': 'HCLTECH',
            'tech mahindra': 'TECHM'
        }
        
        # Check common mappings first
        if company_lower in common_mappings:
            return common_mappings[company_lower]
        
        # 1. Direct exact match
        if company_lower in self.company_to_symbol:
            return self.company_to_symbol[company_lower]
        
        # 2. Check if it's already a symbol
        symbol_upper = company_name.upper()
        if symbol_upper in self.symbol_to_name:
            return symbol_upper
        
        # 3. Normalized name match
        normalized = self._normalize_company_name(company_name)
        if normalized in self.normalized_names:
            return self.normalized_names[normalized]
        
        # 4. Fuzzy matching
        fuzzy_matches = self._fuzzy_match(company_name, threshold=0.7)
        if fuzzy_matches:
            return fuzzy_matches[0][0]  # Return best match
        
        # 5. Keyword-based search
        keyword_matches = self._keyword_search(company_name)
        if keyword_matches:
            return keyword_matches[0][0]  # Return best match
        
        # 6. Partial matching (fallback)
        for key, symbol in self.company_to_symbol.items():
            if (key in company_lower or company_lower in key or 
                any(word in key for word in company_lower.split() if len(word) > 3)):
                return symbol
        
        # 7. Last resort: return normalized input
        return re.sub(r'[^A-Z0-9]', '', company_name.upper())[:10]
    
    def search_companies(self, query: str, limit: int = 10) -> List[Dict[str, str]]:
        """Search for companies with detailed results"""
        results = []
        
        # Combine fuzzy and keyword matches
        fuzzy_matches = self._fuzzy_match(query, threshold=0.4)
        keyword_matches = self._keyword_search(query)
        
        # Merge and deduplicate
        all_matches = {}
        
        for symbol, name, score in fuzzy_matches:
            all_matches[symbol] = {
                'symbol': symbol,
                'company_name': name,
                'match_score': score,
                'match_type': 'fuzzy'
            }
        
        for symbol, name, score in keyword_matches:
            if symbol in all_matches:
                # Combine scores
                all_matches[symbol]['match_score'] = max(all_matches[symbol]['match_score'], score)
                all_matches[symbol]['match_type'] = 'combined'
            else:
                all_matches[symbol] = {
                    'symbol': symbol,
                    'company_name': name,
                    'match_score': score,
                    'match_type': 'keyword'
                }
        
        # Sort by score and return top results
        results = list(all_matches.values())
        results.sort(key=lambda x: x['match_score'], reverse=True)
        
        return results[:limit]
    
    def get_company_display_name(self, symbol: str) -> str:
        """Get display name for a symbol"""
        return self.symbol_to_name.get(symbol.upper(), symbol)
    
    def get_all_companies(self) -> Dict[str, str]:
        """Get all companies mapping"""
        return self.company_to_symbol.copy()
    
    def get_symbol_info(self, symbol: str) -> Dict[str, str]:
        """Get detailed information about a symbol"""
        symbol = symbol.upper()
        if symbol in self.symbol_to_name:
            return {
                'symbol': symbol,
                'company_name': self.symbol_to_name[symbol],
                'normalized_name': self._normalize_company_name(self.symbol_to_name[symbol])
            }
        return {}

# Initialize the global matcher
_matcher = CompanyMatcher()

# Backward compatibility functions
def get_best_symbol(company_name: str) -> str:
    """Get the best stock symbol for a company name"""
    return _matcher.get_best_symbol(company_name)

def get_company_display_name(symbol: str) -> str:
    """Get display name for a symbol"""
    return _matcher.get_company_display_name(symbol)

def get_all_companies() -> Dict[str, str]:
    """Get all companies mapping"""
    return _matcher.get_all_companies()

def search_companies(query: str, limit: int = 10) -> List[Dict[str, str]]:
    """Search for companies with AI-powered matching"""
    return _matcher.search_companies(query, limit)

def get_symbol_info(symbol: str) -> Dict[str, str]:
    """Get detailed symbol information"""
    return _matcher.get_symbol_info(symbol)