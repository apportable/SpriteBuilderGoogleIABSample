IABSample
=========

###IMPORTANT NOTE 
This sample app requires the SpriteBuilder Android plugin at the Indie or Professional tier. 

###Introduction
This In-App billing sample application has the same features as the Google official IAB-Sample, which you can find it [here](https://code.google.com/p/marketbilling/source/browse/v3/src/com/example/android/trivialdrivesample/?r=5f6b7abfd0534acd5bfc7c14436f4500c99e0358#trivialdrivesample%253Fstate%253Dclosed). The only difference is that the app in this repository is written in Objective-C. 
The purpose of this sample is to provide SpriteBuilder developers with a clear way of using Google In App Billing from objective-c
  
###Prerequisite:

  1. Download SpriteBuilder
  2. Install the SpriteBuilder Android Plugin (IMPORTANT NOTE: this will only work on Indie and Pro versions of the plugin)
  3. Find an android phone or buy a new one on [newegg](http://www.newegg.com/Product/ProductList.aspx?Submit=ENE&DEPA=0&Order=BESTMATCH&Description=android&N=-1&isNodeId=1)
  
###Configure on Google Play:

  1. Create an application on the Developer Console.
  2. In that app, create MANAGED in-app items with these IDs: premium, gas.
     
     Set their prices to 0.99 or 1 dollar.
  3. In that app, create a SUBSCRIPTION items with this ID: infinite_gas
     
     Set the price to 0.99 or 1 dollar and the billing recurrence to monthly. 
  4. Make sure your test account (the one you will use to test purchases) is correctly listed in the "testing" section. 
  
     Your test account CANNOT BE THE SAME AS THE PUBLISHER ACCOUNT.
  5. Grab the application's public key (a base-64 string). You can find the application's public key in the "Services & API" page for your application.
     You will need this in the code (at least in the example) and in the Project settings in xcode for publishing
  6. Finish the mandatory sections in the console so that you can publish the app.
     
     It is not necessary to push the application in production. Alpha, and beta should be fine but the app must be published instead of in draft mode.
     
###Publish Project in SpriteBuilder:
  1. Should be all that is necessary on the SpriteBuilder side
  
###Build Project in Xcode:
  1. Replace the public key in MainScene.m, line 184. Replace the string with the public key you got from step 5 in the last section.
  2. Make sure you are on the Android target and select your connected Android device. 
  3. You will need to ensure that you are in a release configuration to upload your first apk to google play.
      This means you cant have debugging enabled in the manifest (for the uploaded apk)
      The build settings are setup to enable builds that are signed with a keystore and a build timestamp so that after initial upload subsequent builds can be debugged.
      
  4. Publish the apk to alpha
  5. Profit.
  
###Feedback:
  
  Please let us know if you have any issues on our [forums](http://forum.spritebuilder.com) under the Android tag.
