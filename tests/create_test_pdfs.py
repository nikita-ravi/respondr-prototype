#!/usr/bin/env python3
"""
Create Test PDF Documents

This script creates sample PDF documents with realistic content for testing
the document metadata extraction pipeline.
"""

import os
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak
from reportlab.lib.enums import TA_CENTER, TA_LEFT

# Create output directory
OUTPUT_DIR = "test_documents"
os.makedirs(OUTPUT_DIR, exist_ok=True)

def create_pdf(filename, title, content_paragraphs):
    """
    Create a PDF document with the given content.

    Args:
        filename: Output PDF filename
        title: Document title
        content_paragraphs: List of content paragraphs
    """
    filepath = os.path.join(OUTPUT_DIR, filename)
    doc = SimpleDocTemplate(filepath, pagesize=letter)

    # Container for the 'Flowable' objects
    elements = []

    # Define styles
    styles = getSampleStyleSheet()

    title_style = ParagraphStyle(
        'CustomTitle',
        parent=styles['Heading1'],
        fontSize=24,
        textColor='darkblue',
        spaceAfter=30,
        alignment=TA_CENTER
    )

    heading_style = ParagraphStyle(
        'CustomHeading',
        parent=styles['Heading2'],
        fontSize=16,
        textColor='darkblue',
        spaceAfter=12,
        spaceBefore=12
    )

    # Add title
    elements.append(Paragraph(title, title_style))
    elements.append(Spacer(1, 0.3 * inch))

    # Add content
    for para in content_paragraphs:
        if para.startswith("## "):
            # Section heading
            elements.append(Paragraph(para[3:], heading_style))
        else:
            # Normal paragraph
            elements.append(Paragraph(para, styles['Normal']))
            elements.append(Spacer(1, 0.15 * inch))

    # Build PDF
    doc.build(elements)
    print(f"Created: {filepath}")


def create_emergency_plan():
    """Create an emergency evacuation plan document."""
    content = [
        "## Document Information",
        "<b>Document Type:</b> Emergency Evacuation Plan",
        "<b>Version:</b> 2.1",
        "<b>Effective Date:</b> 01/15/2024",
        "<b>Author:</b> John Smith",
        "<b>Organization:</b> Acme Corporation",
        "<b>Facility:</b> Building A, Floor 3",
        "<b>Jurisdiction:</b> Virginia (VA)",

        "## Purpose",
        "This emergency evacuation plan establishes procedures for the safe and orderly evacuation "
        "of Building A in the event of fire, natural disaster, or other emergencies requiring "
        "evacuation of the facility.",

        "## Scope",
        "This plan applies to all employees, contractors, and visitors in Building A. It covers "
        "fire emergencies, chemical spills, and natural disasters including floods.",

        "## Roles and Responsibilities",
        "<b>Security Personnel:</b> Security officers will coordinate the evacuation and ensure "
        "all areas are clear. They will also interface with emergency responders.",

        "<b>EHS Team:</b> The Environmental Health and Safety team will assess hazards and "
        "determine when it is safe to re-enter the building.",

        "<b>Facilities Staff:</b> Facilities maintenance personnel will shut down critical "
        "systems and assist with evacuation as needed.",

        "## Emergency Procedures",
        "### Fire Emergency",
        "Upon hearing the fire alarm, all personnel must immediately evacuate using the nearest "
        "exit. Do not use elevators. Proceed to the designated assembly point in the north parking lot.",

        "### Chemical Spill",
        "In case of a chemical spill, alert the EHS team immediately. Evacuate the affected area "
        "and await instructions from trained hazmat personnel.",

        "### Active Shooter",
        "In the event of an active shooter situation, follow the Run-Hide-Fight protocol. "
        "Contact security and 911 immediately.",

        "## Assembly Points",
        "Primary assembly point: North parking lot, near Building A entrance<br/>"
        "Secondary assembly point: South parking lot, near Building C",

        "## Contact Information",
        "Security: (555) 123-4567<br/>"
        "EHS: (555) 123-4568<br/>"
        "Facilities: (555) 123-4569<br/>"
        "Emergency: 911",

        "## Training Requirements",
        "All personnel must complete annual fire safety training and participate in quarterly "
        "evacuation drills. Training records are maintained by HR.",
    ]

    create_pdf("emergency_evacuation_plan.pdf", "Emergency Evacuation Plan - Building A", content)


def create_sop_document():
    """Create a Standard Operating Procedure document."""
    content = [
        "## Document Information",
        "<b>Document Type:</b> Standard Operating Procedure (SOP)",
        "<b>Version:</b> 3.0",
        "<b>Effective Date:</b> 02/01/2024",
        "<b>Author:</b> Sarah Johnson",
        "<b>Organization:</b> Tech Industries Inc",
        "<b>Facility:</b> Room 301, Building B",

        "## Purpose",
        "This Standard Operating Procedure (SOP) defines the process for handling and storing "
        "chemical materials in the laboratory facility.",

        "## Scope",
        "This procedure applies to all laboratory personnel, facilities staff, and contractors "
        "working with or near chemical storage areas in Room 301.",

        "## Responsibilities",
        "<b>Laboratory Personnel:</b> Follow all chemical handling procedures and maintain proper "
        "documentation of chemical inventory.",

        "<b>EHS Coordinator:</b> Conduct monthly inspections of chemical storage areas and ensure "
        "compliance with safety regulations.",

        "<b>Facilities Team:</b> Maintain ventilation systems, emergency showers, and eyewash "
        "stations in proper working order.",

        "## Procedure",
        "### Chemical Receiving",
        "1. Inspect all incoming chemical shipments for damage or leaks<br/>"
        "2. Verify chemical identity and quantity against purchase order<br/>"
        "3. Log chemicals in inventory management system<br/>"
        "4. Transport to designated storage area using appropriate cart",

        "### Storage Requirements",
        "Store incompatible chemicals separately. Flammable materials must be stored in approved "
        "flammable storage cabinets. Corrosive materials require secondary containment.",

        "### Hazard Communication",
        "All chemical containers must be properly labeled with chemical name, hazard warnings, "
        "and date received. Safety Data Sheets (SDS) must be readily accessible.",

        "### Emergency Response",
        "In case of chemical spill, evacuate the area and contact EHS immediately at (555) 234-5678. "
        "For medical emergencies, call 911 and notify the medical team.",

        "### Personal Protective Equipment",
        "Required PPE: Safety glasses, lab coat, nitrile gloves. Additional PPE may be required "
        "based on specific chemical hazards.",

        "## Training",
        "All personnel must complete hazardous materials training before handling chemicals. "
        "Annual refresher training is required.",

        "## References",
        "- OSHA Hazard Communication Standard (29 CFR 1910.1200)<br/>"
        "- EPA Chemical Storage Guidelines<br/>"
        "- Company EHS Manual Section 4.2",
    ]

    create_pdf("chemical_handling_sop.pdf", "SOP: Chemical Handling and Storage", content)


def create_incident_report():
    """Create an incident report document."""
    content = [
        "## Incident Report",
        "<b>Report ID:</b> IR-2024-0042",
        "<b>Document Type:</b> Incident Report",
        "<b>Date of Incident:</b> 01/20/2024",
        "<b>Time:</b> 14:30",
        "<b>Location:</b> Building D, Room 205",
        "<b>Reported By:</b> Mike Davis",
        "<b>Organization:</b> Safety First Corp",

        "## Incident Summary",
        "Employee sustained minor injury (laceration to right hand) while operating machinery "
        "in the production area. Medical attention was provided on-site by company nurse.",

        "## Incident Details",
        "At approximately 14:30 on January 20, 2024, employee John Doe was operating the "
        "packaging machine when his right hand came into contact with a sharp edge, resulting "
        "in a 2-inch laceration.",

        "## Response Actions",
        "<b>Immediate Response:</b><br/>"
        "1. Production supervisor stopped the machine immediately<br/>"
        "2. Medical team was notified at 14:32<br/>"
        "3. Company nurse arrived on scene at 14:35<br/>"
        "4. First aid was administered (wound cleaning and bandaging)<br/>"
        "5. Employee was released to return to light duty work",

        "## Personnel Involved",
        "<b>Injured Party:</b> John Doe, Production Operator<br/>"
        "<b>Medical Personnel:</b> Jane Smith, RN (Company Nurse)<br/>"
        "<b>HR Representative:</b> Tom Wilson<br/>"
        "<b>Security:</b> Officer Rodriguez (secured scene)<br/>"
        "<b>EHS Coordinator:</b> Lisa Chen (incident investigation)",

        "## Root Cause Analysis",
        "Investigation revealed that the machine guard had been removed for maintenance earlier "
        "in the day and was not properly reinstalled. This created a hazardous condition that "
        "led to the injury.",

        "## Corrective Actions",
        "1. All machine guards inspected and verified secure<br/>"
        "2. Maintenance lockout/tagout procedure reviewed with all staff<br/>"
        "3. Additional training scheduled for production team<br/>"
        "4. Daily machine guard inspection checklist implemented",

        "## Classification",
        "Severity: Minor (First Aid Case)<br/>"
        "Type: Occupational Injury<br/>"
        "Body Part: Right Hand<br/>"
        "Lost Time: 0 days",

        "## Follow-up",
        "Employee will be monitored for signs of infection. Follow-up appointment scheduled "
        "with occupational health clinic in 3 days. Return to full duty expected within 5 days.",

        "## Regulatory Reporting",
        "This incident does not meet OSHA recordable criteria as it required only first aid treatment. "
        "No regulatory reporting required. Internal incident log updated.",

        "## Attachments",
        "- Photos of incident scene<br/>"
        "- Employee statement<br/>"
        "- Witness statements<br/>"
        "- Medical treatment record",
    ]

    create_pdf("incident_report_2024_0042.pdf", "Incident Report IR-2024-0042", content)


def main():
    """Create all test PDF documents."""
    print("Creating test PDF documents...")
    print()

    create_emergency_plan()
    create_sop_document()
    create_incident_report()

    print()
    print(f"✓ All test documents created in: {OUTPUT_DIR}/")
    print()
    print("Next steps:")
    print("1. Upload to S3: ./tests/upload_test_docs.sh")
    print("2. Verify processing: python3 tests/verify_processing.py")
    print("3. View dashboard: streamlit run dashboard/dashboard.py")


if __name__ == "__main__":
    main()
