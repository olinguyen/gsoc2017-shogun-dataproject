# Patient Monitoring and Decision Support using Health Data

Github repository for the code for my Google Summer of Code 2017 project with [Shogun Machine Learning Toolbox](shogun.ml). Work for this project was also documented [here](https://olinguyen.github.io/2017-08-21-gsoc-final-post/).

## Abstract

For GSoC2017, I will make use of the Shogun library on health data and show the usefulness of machine learning in applications that could save people's lives and benefit society. More specifically, I want to focus on analyzing health data for applications such as clinical decision support and mortality prediction. The MIMIC database will be used, which is comprised of information relating to patients admitted to the ICU at a large hospital. The data mainly includes demographic, administrative, and clinical data from over 45,000 critical care patients. The project will be divided into two parts: In the first part, I perform data cleaning and apply various machine learning algorithms on the MIMIC dataset for mortality prediction, hospital readmission and length of stay. In the final part, I will explore more novel methods like LSTMs to exploit the time-series data. Recent research has shown good results of using deep learning on electronic health records.

## Notebooks

* MIMIC tutorial & data exploration
* Dataset visualization
* Basic machine learning model for predicting mortality & hospital length of stay
* Feature selection & dimensionality reduction
* Machine learning model with temporal and lagged features
* Basic neural networks

## Subfolders

`sql`: Contains sql files for queries on the MIMIC database
`scripts`: Utility functions used in some of the notebooks