
#@ File (label = "Input directory", value = "//cci02.liv.ac.uk/cci/private/Marie/Image Analysis/2022-01-13-RAVAL-Haitham-AlAbiad-bacteria-counting-live-dead/Fiji_script_test_folder/input", style = "directory") input
#@ File (label = "Output directory", value = "//cci02.liv.ac.uk/cci/private/Marie/Image Analysis/2022-01-13-RAVAL-Haitham-AlAbiad-bacteria-counting-live-dead/Fiji_script_test_folder/output", style = "directory") output
#@ String (label = "File suffix", value = ".czi", persist=false) suffix
#@ Double(label = "Fraction for prominence calculation", value=0.02, persist=false) prominence_fraction
#@ Integer(label = "Bernsen radius", value=15, persist=false) Bernsen_radius



processFolder(input);

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


function processFile(input, output, file) {
	//print("Processing: " + input + File.separator + file);
	//print("Processing folder: " + input);
	print("Processing: " + file);
	open(input + File.separator + file);
	Image_Title = getTitle();	

	
	Background_removed_Title = BackgroundRemoval(Image_Title);
	Segmentation(Background_removed_Title);
	Counting();
}

function BackgroundRemoval(Image_Title){
	selectWindow(Image_Title);
	run("Duplicate...", "duplicate");
	Duplicate_Title = getTitle();
	run("Gaussian Blur...", "sigma=20 stack");
	imageCalculator("Subtract create stack", Image_Title , Duplicate_Title);
	run("Median...", "radius=1 stack");
	Background_removed_Title = getTitle(); 
	selectWindow(Duplicate_Title); 
	close();
	return Background_removed_Title;
}

function Segmentation(Background_removed_Title){
	// find maxima as an approximation of individual bacteria. For information on prominence, see here: https://forum.image.sc/t/new-maxima-finder-menu-in-fiji/25504/5
	selectImage(Background_removed_Title);	
	run("Duplicate...", "duplicate");
	Duplicate_Title = getTitle();
	run("Split Channels");
	
	selectImage("C1-" + Duplicate_Title);
	getMinAndMax(min, max);
	Prominence = max * prominence_fraction;
	prominence_output_label_C1 = "calculated from intensity values.";
	print("Segmenting particles of Channel1 via Find Maxima....");
	run("Find Maxima...", "prominence=Prominence output=[Segmented Particles]");
	live_particle_segmentation_C1 = "live particle segmentation Channel1";
	rename(live_particle_segmentation_C1);

	selectImage("C1-" + Duplicate_Title);	
	setAutoThreshold("Otsu dark");
	//run("Threshold...");
	setOption("BlackBackground", false);
	run("Convert to Mask", "method=Otsu background=Dark calculate");
	/*
	run("8-bit");
	print("Auto local threshold using Bernsen method.");
	run("Auto Local Threshold", "method=Bernsen radius=Bernsen_radius parameter_1=0 parameter_2=0 white");
	*/
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
	print("Segmenting particles of Channel2 via Find Maxima....");
	run("Find Maxima...", "prominence=Prominence output=[Segmented Particles]");
	live_particle_segmentation_C2 = "live particle segmentation Channel2";
	rename(live_particle_segmentation_C2);

	selectImage("C2-" + Duplicate_Title);
	setAutoThreshold("Otsu dark");
	//run("Threshold...");
	setOption("BlackBackground", false);
	run("Convert to Mask", "method=Otsu background=Dark calculate");
	/*
	run("8-bit");
	print("Auto local threshold using Bernsen method.");
	run("Auto Local Threshold", "method=Bernsen radius=Bernsen_radius parameter_1=0 parameter_2=0 white");
	*/
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
	
}

function Counting(){
	run("Set Measurements...", "area display redirect=None decimal=3");
	selectWindow("Live"); 
	run("Select None");
	run("Measure");
	liveAreaFraction = getValue("%Area");
	run("Select None");
	print("Live area fraction: " + liveAreaFraction); 
	setOption("BlackBackground", false);
	run("Convert to Mask");
	run("Analyze Particles...", "size=0.1-Infinity circularity=0.80-1.00 clear add");
	liveCount = roiManager("count") + 1;
	print("Live bacteria count: " + liveCount); 

	run("Select None");
	roiManager("Reset");

	selectWindow("Dead"); 
	run("Select None");
	run("Measure");
	deadAreaFraction = getValue("%Area");
	run("Select None");
	print("Dead area fraction: " + deadAreaFraction); 
	setOption("BlackBackground", false);
	run("Convert to Mask");
	run("Analyze Particles...", "size=0.1-Infinity circularity=0.80-1.00 clear add");
	deadCount = roiManager("count") + 1;
	print("Dead bacteria count: " + deadCount); 

	run("Select None");
	roiManager("Reset");

	selectWindow("Total"); 
	run("Select None");
	run("Measure");
	totalAreaFraction = getValue("%Area");
	run("Select None");
	print("Dead area fraction: " + totalAreaFraction); 
	setOption("BlackBackground", false);
	run("Convert to Mask");
	run("Analyze Particles...", "size=0.1-Infinity circularity=0.80-1.00 clear add");
	totalCount = roiManager("count") + 1;	
	print("Total bacteria count: " + totalCount); 

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
	Array.print(results); 

	resultsRowLabels = newArray("Live fraction of image (%)", "Dead fraction of image (%)", "Total fraction of image (%)", "Live/Dead area ratio", "Live bacteria count", "Dead bacteria count", "Live/Dead count ratio");
	Array.print(resultsRowLabels); 

	// Generate new table from results lists for display and data saving purposes. 
	Table.create("Results Table");
	// set four new columns
	Table.setColumn("Parameter", resultsRowLabels);
	Table.setColumn("Results", results);
	
	//clean up
    if (isOpen("Results")) {
         selectWindow("Results"); 
         run("Close" );
    {

	
	}
