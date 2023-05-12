/****** Object:  UserDefinedFunction [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_Additional_ConcessionFlight]    Script Date: 12/05/2023 12:42:35 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ===============================================================================================================================================
-- Description: Function for Businees Rules "add concession flight"
--
--	2019-10-11	Juan Camilo Zuluaga: Created function
--	2022-07-28	Sebastián Jaramillo: Se ajusta RN VivaColombia para indicar explícitamente servicios internacionales
--	2023-04-30	Sebastián Jaramillo: Se quita el cobro de concesión para la operación de AVA SAI BOGEXT facturada a traves de SAI
-- ===============================================================================================================================================
ALTER FUNCTION [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_Additional_ConcessionFlight](
	@AirportId INT,
	@ServiceTypeStageId  INT,
	@AirplaneType NVARCHAR(50),
	@FlightArrivingCanceled BIT,
	@CompanyId INT,
	@BillingToCompany INT,
	@Date DATE,
	@DestinationId INT
)
RETURNS @Result TABLE(ROW INT IDENTITY, AdditionalService BIT, AdditionalQuantity INT, AdditionalServiceName VARCHAR(150))
AS
BEGIN
	DECLARE	@ExtraText VARCHAR(50) = ''

	IF (@AirportId = 47 AND @Date >= '2021-02-01') --PSO A PARTIR DEL PRIMERO DE FEBRERO NO MANEJA COBRO DE IVAR
	BEGIN
		INSERT @Result VALUES (0, 0, NULL)
		RETURN
	END

	IF (@CompanyId = 1 AND @BillingToCompany = 87 AND @Date >= '2023-04-19') --AVIANCA / SAI                         
	BEGIN
		INSERT @Result VALUES (0, 0, NULL)
		RETURN
	END

	IF (@CompanyId = 60 AND @BillingToCompany = 90) --VIVA COLOMBIA                           
	BEGIN
		IF (CIOServicios.UFN_CIO_InternationalFlight(@AirportId, @DestinationId) = 1)
		BEGIN
			SET @ExtraText = ' INTERNACIONAL'
		END
	END

	IF (@AirportId = 47 AND @Date >= '2021-02-01') --PSO A PARTIR DEL PRIMERO DE FEBRERO NO MANEJA COBRO DE IVAR
	BEGIN
		INSERT @Result VALUES (0, 0, NULL)
		RETURN
	END

	IF (@ServiceTypeStageId  IN (1, 2, 3, 5) AND @FlightArrivingCanceled = 0 AND @AirportId NOT IN(10, 17, 42, 26, 25, 34, 9, 12, 43, 60)) --BAQ, CTG, MZL, FLA, EYP, LET, AXM, BOG, NVA, VVC (Se cobra un valor sobre el total de ingresos)
	BEGIN
		INSERT @Result VALUES (1, 1, 'COBRO CONCESION VUELO ATENTIDO' + @ExtraText + ' ' + @AirplaneType)
	END
	ELSE
	BEGIN
		INSERT @Result VALUES (0, 0, NULL)
	END

	IF (@Date >= '2019-11-01' AND @ServiceTypeStageId IN (1, 2, 5) AND @FlightArrivingCanceled = 0 AND @AirportId = 17) --CTG A PARTIR DEL 2019-11-01
	BEGIN
		INSERT @Result VALUES (1, 1, 'COBRO CONCESION VUELO ATENTIDO' + @ExtraText + ' ' + @AirplaneType)
	END

	RETURN
END