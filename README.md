# TalkingData AdTracking Fraud Detection
This project is part of the Data Science Formation taugh by Data Science Academy: https://www.datascienceacademy.com.br/
<br />
This original project is posted on https://www.kaggle.com/c/talkingdata-adtracking-fraud-detection
<br />
<h3>Files Description</h3>
- <b>.csv files:</b> contain the datasets<br />
- <b>Fraud detect.R:</b> contain the script of the project<br />
- <b>Fraud detect.Rmd:</b> contain the markdown script<br />
- <b>Fraud detect.html:</b> <u>this file is the compiled report</u>
<hr />
<h2>Description</h2>
Fraud risk is everywhere, but for companies that advertise online, click fraud can happen at an overwhelming volume, resulting in misleading click data and wasted money. Ad channels can drive up costs by simply clicking on the ad at a large scale. With over 1 billion smart mobile devices in active use every month, China is the largest mobile market in the world and therefore suffers from huge volumes of fradulent traffic.
<br /><br />
TalkingData, China’s largest independent big data service platform, covers over 70% of active mobile devices nationwide. They handle 3 billion clicks per day, of which 90% are potentially fraudulent. Their current approach to prevent click fraud for app developers is to measure the journey of a user’s click across their portfolio, and flag IP addresses who produce lots of clicks, but never end up installing apps. With this information, they've built an IP blacklist and device blacklist.
<br /><br />
While successful, they want to always be one step ahead of fraudsters and have turned to the Kaggle community for help in further developing their solution. In their 2nd competition with Kaggle, you’re challenged to build an algorithm that predicts whether a user will download an app after clicking a mobile app ad. To support your modeling, they have provided a generous dataset covering approximately 200 million clicks over 4 days!
<br />
<h2>Data fields</h2>
Each row of the training data contains a click record, with the following features.
<br />
<b>ip:</b> ip address of click.<br />
<b>app:</b> app id for marketing.<br />
<b>device:</b> device type id of user mobile phone (e.g., iphone 6 plus, iphone 7, huawei mate 7, etc.)<br />
<b>os:</b> os version id of user mobile phone<br />
<b>channel:</b> channel id of mobile ad publisher<br />
<b>click_time:</b> timestamp of click (UTC)<br />
<b>attributed_time:</b> if user download the app for after clicking an ad, this is the time of the app download<br />
<b>is_attributed:</b> the target that is to be predicted, indicating the app was downloaded<br />
Note that ip, app, device, os, and channel are encoded.<br />
