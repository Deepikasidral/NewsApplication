#!/usr/bin/env python3
"""
MCP Financial Analysis Terminal
Interactive terminal for company analysis using MCP server
"""

import os
import sys
from datetime import datetime
from pytz import timezone

# Add the parent directory to sys.path to import mcp_server modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from llm import ask_llm
from config import OPENAI_API_KEY, MONGO_URI

IST = timezone("Asia/Kolkata")

def print_banner():
    """Print welcome banner"""
    print("\n" + "="*60)
    print("🚀 MCP FINANCIAL ANALYSIS TERMINAL")
    print("="*60)
    print("📊 Real-time company analysis powered by Finedge API")
    print("🤖 AI-driven insights using OpenAI GPT-4o-mini")
    print("📰 News sentiment and market data integration")
    print("="*60)
    print(f"🕐 Session started: {datetime.now(IST).strftime('%Y-%m-%d %H:%M:%S IST')}")
    print("="*60)

def print_help():
    """Print available commands"""
    print("\n📋 AVAILABLE COMMANDS:")
    print("  • Ask about any company: 'TCS analysis', 'Reliance financial health'")
    print("  • Market queries: 'market news today', 'yesterday performance'")
    print("  • News search: 'search inflation news', 'banking sector news'")
    print("  • Type 'help' - Show this help")
    print("  • Type 'exit' - Quit terminal")
    print("  • Type 'clear' - Clear screen")
    print("\n💡 EXAMPLE QUERIES:")
    print("  → 'What is TCS analysis?'")
    print("  → 'Infosys financial health'")
    print("  → 'HDFC Bank comprehensive analysis'")
    print("  → 'Market sentiment today'")
    print("  → 'Search tech stocks news'")

def clear_screen():
    """Clear terminal screen"""
    os.system('cls' if os.name == 'nt' else 'clear')

def check_environment():
    """Check if required environment variables are set"""
    missing = []
    
    if not OPENAI_API_KEY:
        missing.append("OPENAI_API_KEY")
    
    if not os.getenv("FINEDGE_API_TOKEN"):
        missing.append("FINEDGE_API_TOKEN")
        
    if not MONGO_URI:
        missing.append("MONGO_URI")
    
    if missing:
        print("❌ MISSING ENVIRONMENT VARIABLES:")
        for var in missing:
            print(f"   • {var}")
        print("\n💡 Please set these in your .env file")
        return False
    
    print("✅ Environment check passed")
    return True

def main():
    """Main terminal loop"""
    print_banner()
    
    # Check environment
    if not check_environment():
        print("\n❌ Environment setup incomplete. Exiting...")
        return
    
    print_help()
    
    print("\n🎯 Ready for your questions!")
    
    while True:
        try:
            # Get user input
            user_input = input("\n💬 Ask me: ").strip()
            
            # Handle commands
            if user_input.lower() in ['exit', 'quit', 'q']:
                print("\n👋 Thanks for using MCP Financial Terminal!")
                print("🚀 Session ended at", datetime.now(IST).strftime('%H:%M:%S IST'))
                break
                
            elif user_input.lower() == 'help':
                print_help()
                continue
                
            elif user_input.lower() == 'clear':
                clear_screen()
                print_banner()
                continue
                
            elif not user_input:
                print("❓ Please enter a question or 'help' for commands")
                continue
            
            # Process question
            print(f"\n🔍 Processing: {user_input}")
            print("⏳ Fetching data and generating analysis...")
            
            # Get AI response
            response = ask_llm(user_input)
            
            # Display response
            print("\n" + "="*60)
            print("🤖 AI ANALYSIS:")
            print("="*60)
            print(response)
            print("="*60)
            
        except KeyboardInterrupt:
            print("\n\n👋 Session interrupted. Goodbye!")
            break
            
        except Exception as e:
            print(f"\n❌ Error: {str(e)}")
            print("💡 Try rephrasing your question or type 'help'")

if __name__ == "__main__":
    main()