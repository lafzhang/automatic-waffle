output = getArgument();
if (output == "") exit("Expected an output directory");
setBatchMode(true);
newImage("synthetic-fixture", "8-bit black", 4, 3, 1);
for (y = 0; y < getHeight(); y++) {
    for (x = 0; x < getWidth(); x++) {
        setPixel(x, y, 10 * y + x);
    }
}
getStatistics(area, mean, minimum, maximum);
saveAs("Tiff", output + "/fixture.tif");
File.saveString(
    "width,height,count,mean,min,max\n" +
    getWidth() + "," + getHeight() + "," + area + "," + mean + "," + minimum + "," + maximum + "\n",
    output + "/stats.csv");
File.saveString(getVersion() + "\n", output + "/imagej-version.txt");
close();
