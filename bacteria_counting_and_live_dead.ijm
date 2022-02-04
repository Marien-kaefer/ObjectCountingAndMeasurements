/*
Macro to count bacteria in a field of view and quantify the live/dead ratio of the identified bacteria stained with a live dead kit.


												- Written by Marie Held [mheldb@liverpool.ac.uk] February 2022
												  Liverpool CCI (https://cci.liverpool.ac.uk/)
MIT License
Copyright (c) [2022] [Marie Held {mheldb@liverpool.ac.uk}, Image Analyst Liverpool CCI (https://cci.liverpool.ac.uk/)]
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, 
modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#@ File (label = "Input directory", value = "//cci02.liv.ac.uk/cci/private/Marie/Image Analysis/2022-01-13-RAVAL-Haitham-AlAbiad-bacteria-counting-live-dead/Fiji_script_test_folder/input", style = "directory") input
#@ File (label = "Output directory", value = "//cci02.liv.ac.uk/cci/private/Marie/Image Analysis/2022-01-13-RAVAL-Haitham-AlAbiad-bacteria-counting-live-dead/Fiji_script_test_folder/output", style = "directory") output
#@ String (label = "File suffix", value = ".czi", persist=false) suffix
#@ Double(label = "Background removal via Gaussian filter subtraction (Sigma)", value=20, persist=false) background_removal_sigma
#@ Double(label = "Image smoothing - Median filter (Sigma)", value=2, persist=false) median_filter_smoothing_sigma
#@ String(label = "Thresholding?", choices = {"Global (Otsu)", "Local (Bernsen)"}, style = "radioButtonHorizontal", persist=false)  thresholding_choice
#@ Integer(label = "Bernsen radius (px; only applicable for local filtering)", value=15, persist=false) Bernsen_radius
#@ Double(label = "Fraction for prominence calculation", value=0.02, persist=false) prominence_fraction
#@ Double(label = "Object min. size (micron^2)", value=0, persist=false) object_min_size
#@ Float(label = "Object max. size (micron^2)", value=10000, persist=false) object_max_size
#@ Double(label = "Object min. circularity", value=0.0, persist=false) object_min_circularity
#@ Double(label = "Object max. circularity", value=1.0, persist=false) object_max_circularity


processFolder(input);
beep()
print("All done! Please check the output folder for the generated results files."); 


// FUNCTIONS 

// function to scan folders/subfolders/files to find files with correct suffix
function processFolder(input) {
	list = getFileList(input);
	list = Array.sort(list);
	for (i = 0; i < list.length; i++) {
		if(File.isDirectory(input + File.separator + list[i]))
			processFolder(input + File.separator + list[i]);
		if(endsWith(list[i], suffix))
			processFile(input, output, list[i]);
	}
}

//function to process a single file
function processFile(input, output, file) {
	//print("Processing: " + input + File.separator + file);
	//print("Processing folder: " + input);
	print("Processing: " + file);
	open(input + File.separator + file);
	Image_Title = getTitle();	
	Image_Title_Without_Extension = file_name_remove_extension(Image_Title);
	
	Background_removed_Title = Background_removal(Image_Title, background_removal_sigma);
	Prominence = Segmentation(Background_removed_Title, thresholding_choice);
	Counting(Image_Title_Without_Extension);
	make_mask_stack();
	selectWindow(Background_removed_Title); 
	saveAs("Tiff", output + File.separator + Image_Title_Without_Extension + "_BG-removed-smoothed.tif");
	close();
	selectWindow(Image_Title); 
	close();
	write_input_parameters_to_file(Image_Title_Without_Extension, background_removal_sigma, median_filter_smoothing_sigma, thresholding_choice, Bernsen_radius, object_min_size, object_max_size, object_min_circularity, object_max_circularity, Prominence); 
 
}

function Background_removal(Image_Title, background_removal_sigma){
	selectWindow(Image_Title);
	run("Duplicate...", "duplicate");
	Duplicate_Title = getTitle();
	run("Gaussian Blur...", "sigma=" + background_removal_sigma + " stack");
	imageCalculator("Subtract create stack", Image_Title , Duplicate_Title);
	run("Median...", "radius=" + median_filter_smoothing_sigma + " stack");
	Background_removed_Title = getTitle(); 
	selectWindow(Duplicate_Title); 
	close();
	return Background_removed_Title;
}

function Segmentation(Background_removed_Title, thresholding_choice){
	// find maxima as an approximation of individual bacteria. For information on prominence, see here: https://forum.image.sc/t/new-maxima-finder-menu-in-fiji/25504/5
	selectImage(Background_removed_Title);	
	run("Duplicate...", "duplicate");
	Duplicate_Title = getTitle();
	run("Split Channels");
	
	selectImage("C1-" + Duplicate_Title);
	getMinAndMax(min, max);
	Prominence = max * prominence_fraction;
	prominence_output_label_C1 = "calculated from intensity values.";
	//print("Segmenting particles of Channel1 via Find Maxima....");
	run("Find Maxima...", "prominence=Prominence output=[Segmented Particles]");
	live_particle_segmentation_C1 = "live particle segmentation Channel1";
	rename(live_particle_segmentation_C1);

	selectImage("C1-" + Duplicate_Title);	
	if (thresholding_choice == "Global (Otsu)"){   
		setAutoThreshold("Otsu dark");
		//run("Threshold...");
		setOption("BlackBackground", false);
		run("Convert to Mask", "method=Otsu background=Dark calculate");
	} else if (thresholding_choice == "Local (Bernsen)"){
		run("8-bit");
		print("Auto local threshold using Bernsen method.");
		run("Auto Local Threshold", "method=Bernsen radius=Bernsen_radius parameter_1=0 parameter_2=0 white");
	}
	
	mask_Title_C1 = getTitle();

	setPasteMode("AND");
	selectImage(live_particle_segmentation_C1);
	run("Copy");
	selectImage("C1-" + Duplicate_Title);
	run("Paste");

	selectImage("C2-" + Duplicate_Title);
	getMinAndMax(min, max);
	Prominence = max * prominence_fraction;
	prominence_output_label_C2 = "calculated from intensity values.";
	//run("Median...", "radius=1");
	//print("Segmenting particles of Channel2 via Find Maxima....");
	run("Find Maxima...", "prominence=Prominence output=[Segmented Particles]");
	live_particle_segmentation_C2 = "live particle segmentation Channel2";
	rename(live_particle_segmentation_C2);

	selectImage("C2-" + Duplicate_Title);

	if (thresholding_choice == "Global (Otsu)"){   
		setAutoThreshold("Otsu dark");
		//run("Threshold...");
		setOption("BlackBackground", false);
		run("Convert to Mask", "method=Otsu background=Dark calculate");
	} else if (thresholding_choice == "Local (Bernsen)"){
		run("8-bit");
		print("Auto local threshold using Bernsen method.");
		run("Auto Local Threshold", "method=Bernsen radius=Bernsen_radius parameter_1=0 parameter_2=0 white");
	}
	
	mask_Title_C2 = getTitle();

	setPasteMode("AND");
	selectImage(live_particle_segmentation_C2);
	run("Copy");
	selectImage("C2-" + Duplicate_Title);
	run("Paste");

	selectWindow(live_particle_segmentation_C1); 
	close();
	selectWindow(live_particle_segmentation_C2); 
	close();

	imageCalculator("Subtract create", "C1-" + Duplicate_Title ,"C2-" + Duplicate_Title);
	rename("Live"); 
	imageCalculator("Add create", "C1-" + Duplicate_Title ,"C2-" + Duplicate_Title);
	rename("Total");
	selectWindow("C2-" + Duplicate_Title); 
	rename("Dead"); 
	selectWindow("C1-" + Duplicate_Title); 
	close(); 
	
	return Prominence
	
}

function Counting(Image_Title_Without_Extension){
	run("Set Measurements...", "area area_fraction display redirect=None decimal=3");
	selectWindow("Live"); 
	run("Select None");
	run("Measure");
	totalImageArea = getValue("Area");
	run("Select None");
	setOption("BlackBackground", false);
	run("Convert to Mask");
	run("Analyze Particles...", "size=object_min_size-object_max_size circularity=object_min_circularity-object_max_circularity clear add summarize");
	selectWindow("Summary");
	IJ.renameResults("Summary","Results");
	liveCount = getResult("Count",0);
	liveAreaFraction = getResult("%Area"); 
	//print("Live bacteria count: " + liveCount + ";  Live bacteria area fraction (%): " + liveAreaFraction); 
	ROI_count = roiManager("count");	
	if (ROI_count <0) {
		//do nothing	
	}
	if (ROI_count == 0){
		roiManager("Save", output + File.separator + Image_Title_Without_Extension + "_live-fraction.roi");	
	} 
	else if (ROI_count >= 1){
		roiManager("Save", output + File.separator + Image_Title_Without_Extension + "_live-fraction.zip");	
	}
	
	run("Select None");
	roiManager("Reset");

	selectWindow("Dead"); 
	run("Select None");
	setOption("BlackBackground", false);
	run("Convert to Mask");
	run("Analyze Particles...", "size=object_min_size-object_max_size circularity=object_min_circularity-object_max_circularity clear add summarize");
	selectWindow("Summary");
	IJ.renameResults("Summary","Results");	
	deadCount = getResult("Count",0);
	deadAreaFraction = getResult("%Area"); 
	//print("Dead bacteria count: " + deadCount + ";  Dead bacteria area fraction (%): " + deadAreaFraction); 
	ROI_count = roiManager("count");	
	if (ROI_count <0) {
		//do nothing
	}
	if (ROI_count == 0){
		roiManager("Save", output + File.separator + Image_Title_Without_Extension + "_dead-fraction.roi");	
	} 
	else if (ROI_count >= 1){
		roiManager("Save", output + File.separator + Image_Title_Without_Extension + "_dead-fraction.zip");	
	}
	
	run("Select None");
	roiManager("Reset");

	selectWindow("Total");  
	run("Select None");
	setOption("BlackBackground", false);
	run("Convert to Mask");
	run("Analyze Particles...", "size=object_min_size-object_max_size circularity=object_min_circularity-object_max_circularity clear add summarize");
	selectWindow("Summary");
	IJ.renameResults("Summary","Results");
	totalCount = getResult("Count",0);
	totalAreaFraction =  getResult("%Area"); 
	//print("Total bacteria count: " + totalCount + ";  Total bacteria area fraction (%): " + totalAreaFraction); 
	ROI_count = roiManager("count");	
	if (ROI_count <0) {
		//do nothing
	}
	if (ROI_count == 0){
		roiManager("Save", output + File.separator + Image_Title_Without_Extension + "_total-fraction.roi");	
	} 
	else if (ROI_count >= 1){
		roiManager("Save", output + File.separator + Image_Title_Without_Extension + "_total-fraction.zip");	
	}
	
	run("Select None");
	roiManager("Reset");

	liveDeadAreaRatio = liveAreaFraction / deadAreaFraction;
	liveDeadCountRatio = liveCount/deadCount; 

	results = newArray; 
	results[0] = liveAreaFraction;
	results[1] = deadAreaFraction;
	results[2] = totalAreaFraction;
	results[3] = liveDeadAreaRatio; 
	results[4] = liveCount; 
	results[5] = deadCount; 
	results[6] = liveDeadCountRatio; 
	//Array.print(results); 

	resultsRowLabels = newArray("Live fraction of image (%)", "Dead fraction of image (%)", "Total fraction of image (%)", "Live/Dead area ratio", "Live bacteria count", "Dead bacteria count", "Live/Dead count ratio");
	//Array.print(resultsRowLabels); 

	// Generate new table from results lists for display and data saving purposes. 
	Table.create(Image_Title_Without_Extension + "_Results-Table");
	// set four new columns
	Table.setColumn("Parameter", resultsRowLabels);
	Table.setColumn("Results", results);
	//saveAs("Results", "//cci02.liv.ac.uk/cci/private/Marie/Image Analysis/2022-01-13-RAVAL-Haitham-AlAbiad-bacteria-counting-live-dead/Fiji_script_test_folder/output/Staph CC i4Results Table.csv");
	saveAs("Results", output + File.separator + Image_Title_Without_Extension + "_Results-Table.csv");
	//close(); 
	//clean up
    if (isOpen("Results")) {
         selectWindow("Results"); 
         run("Close" );
    }
}

function make_mask_stack(){
	maskStackName = Image_Title_Without_Extension + "_dead-live-total-masks";
	run("Images to Stack", "use");
	run("Invert LUT");
	saveAs("Tiff", output + File.separator + maskStackName + ".tif");
	//print("Saved as: " + output + File.separator + maskStackName + ".tif");
	close();
}

function write_input_parameters_to_file(Image_Title_Without_Extension, background_removal_sigma, median_filter_smoothing_sigma, thresholding_choice, Bernsen_radius, object_min_size, object_max_size, object_min_circularity, object_max_circularity, Prominence){ 
	parameters_output_file = File.open(output + File.separator + Image_Title_Without_Extension + "_analysis-parameters.txt"); 
	print(parameters_output_file, "Gaussian filter sigma for background removal: " + background_removal_sigma);
	print(parameters_output_file, "Median filter sigma for smooting: " + median_filter_smoothing_sigma);
	print(parameters_output_file, "Thresholding method: " + thresholding_choice);
    print(parameters_output_file, "Bernsen radius (only applied with local thresholding option): " + Bernsen_radius);
    print(parameters_output_file, "Fraction for prominence calculation: " + prominence_fraction);
    print(parameters_output_file, "Prominence (calculated from intensity values): " + Prominence);
    print(parameters_output_file, "Object min. size (micron^2): " + object_min_size);
    print(parameters_output_file, "Object max. size (micron^2): " + object_max_size);
    print(parameters_output_file, "Object min. circularity: " + object_min_circularity);
    print(parameters_output_file, "Object max. circularity: " + object_max_circularity);
    //print(parameters_output_file, "Processed Image: " + processed_image);
	File.close(parameters_output_file)
}

function file_name_remove_extension(file_name){
	dotIndex = lastIndexOf(file_name, "." ); 
	file_name_without_extension = substring(file_name, 0, dotIndex );
	//print( "Name without extension: " + file_name_without_extension );
	return file_name_without_extension;
}
