package com.rupeeletter.newsapp

import android.view.LayoutInflater
import android.widget.Button
import android.widget.TextView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import com.google.android.gms.ads.nativead.MediaView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class NativeAdFactoryExample(private val layoutInflater: LayoutInflater) :
    GoogleMobileAdsPlugin.NativeAdFactory {

    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {

        val adView = layoutInflater.inflate(
            R.layout.native_ad,
            null
        ) as NativeAdView

        val headline = adView.findViewById<TextView>(R.id.ad_headline)
        val body = adView.findViewById<TextView>(R.id.ad_body)
        val cta = adView.findViewById<Button>(R.id.ad_call_to_action)
        val mediaView = adView.findViewById<MediaView>(R.id.ad_media)

        // Set data
        headline.text = nativeAd.headline
        body.text = nativeAd.body ?: ""
        cta.text = nativeAd.callToAction ?: ""

        // 🔥 IMPORTANT (IMAGE)
        adView.mediaView = mediaView
        mediaView.setMediaContent(nativeAd.mediaContent)

        // Required bindings
        adView.headlineView = headline
        adView.bodyView = body
        adView.callToActionView = cta

        adView.setNativeAd(nativeAd)

        return adView
    }
}