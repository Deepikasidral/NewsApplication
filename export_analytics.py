"""
Analytics Export Script
Fetches app analytics data and exports to Excel file
"""
import requests
import pandas as pd
from datetime import datetime
import urllib3

# Disable SSL warnings (since using self-signed certificate)
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# API Configuration - Try both HTTPS and HTTP
API_URLS = [
    "http://13.51.242.86:5000/api/users/profile/analytics/dashboard",
    "https://13.51.242.86:5000/api/users/profile/analytics/dashboard"
]

def fetch_analytics():
    """Fetch analytics data from API"""
    for api_url in API_URLS:
        try:
            print(f"📊 Trying {api_url.split('://')[0].upper()}...")
            response = requests.get(api_url, verify=False, timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                if data.get('success'):
                    print(f"✅ Connected successfully via {api_url.split('://')[0].upper()}")
                    return data.get('analytics', [])
                else:
                    print("❌ API returned unsuccessful response")
            else:
                print(f"❌ Status code: {response.status_code}")
                
        except requests.exceptions.SSLError:
            print(f"❌ SSL Error - trying next option...")
            continue
        except requests.exceptions.ConnectionError as e:
            print(f"❌ Connection Error - trying next option...")
            continue
        except Exception as e:
            print(f"❌ Error: {e}")
            continue
    
    return None

def export_to_excel(analytics_data):
    """Export analytics data to Excel file"""
    try:
        if not analytics_data:
            print("❌ No data to export")
            return
        
        # Create DataFrame
        df = pd.DataFrame(analytics_data)
        
        # Reorder columns
        columns_order = ['name', 'email', 'appOpens', 'totalMinutes', 'sessionCount', 'avgSessionMinutes', 'cardsViewed']
        df = df[columns_order]
        
        # Rename columns for better readability
        df.columns = ['Name', 'Email', 'App Opens', 'Total Time (min)', 'Sessions', 'Avg Session (min)', 'Cards Viewed']
        
        # Generate filename with timestamp
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"analytics_report_{timestamp}.xlsx"
        
        # Export to Excel
        df.to_excel(filename, index=False, sheet_name='Analytics')
        
        print(f"✅ Analytics exported successfully to: {filename}")
        print(f"📈 Total users: {len(df)}")
        print(f"📊 Total app opens: {df['App Opens'].sum()}")
        print(f"⏱️  Total time spent: {df['Total Time (min)'].sum()} minutes")
        print(f"📰 Total cards viewed: {df['Cards Viewed'].sum()}")
        
    except Exception as e:
        print(f"❌ Error exporting to Excel: {e}")

def main():
    print("=" * 50)
    print("📱 RupeeLetter Analytics Export Tool")
    print("=" * 50)
    
    # Fetch data
    analytics_data = fetch_analytics()
    
    if analytics_data:
        # Export to Excel
        export_to_excel(analytics_data)
    else:
        print("❌ Failed to fetch analytics data")
    
    print("=" * 50)

if __name__ == "__main__":
    main()
