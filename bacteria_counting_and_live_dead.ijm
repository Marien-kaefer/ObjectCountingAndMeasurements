
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
	run("8-bit");
	print("Auto local threshold using Bernsen method.");
	run("Auto Local Threshold", "method=Bernsen radius=Bernsen_radius parameter_1=0 parameter_2=0 white");
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
	run("8-bit");
	print("Auto local threshold using Bernsen method.");
	run("Auto Local Threshold", "method=Bernsen radius=Bernsen_radius parameter_1=0 parameter_2=0 white");
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